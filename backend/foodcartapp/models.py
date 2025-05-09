from django.db import models
from django.core.validators import MinValueValidator

from django.db.models import Count, Sum, F
from phonenumber_field.modelfields import PhoneNumberField

from django.core.exceptions import ValidationError
from geocoder.models import AddressCoordinates

from foodcartapp.utils import calculate_distance, logger


def validate_positive(value):
    if value <= 0:
        raise ValidationError("Итоговая цена не может быть отрицательной.")


class Order(models.Model):
    STATUS_CHOICES = [
        ("new", "Новый"),
        ("processing", "В обработке"),
        ("restaurant", "Передан в ресторан"),
        ("delivery", "У курьера"),
        ("completed", "Завершён"),
    ]

    status = models.CharField(
        "Статус", max_length=20, choices=STATUS_CHOICES, default="new", db_index=True
    )

    PAYMENT_METHOD_CHOICES = [
        ("electronic", "Электронно"),
        ("cash", "Наличные"),
    ]

    payment_method = models.CharField(
        "Способ оплаты",
        max_length=20,
        choices=PAYMENT_METHOD_CHOICES,
        default="cash",
        db_index=True,
    )

    restaurant = models.ForeignKey(
        "Restaurant",
        verbose_name="Исполняющий ресторан",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="orders",
    )

    comment = models.TextField(
        "Комментарий", blank=True, help_text="Дополнительная информация о заказе"
    )

    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)

    firstname = models.CharField("Имя", max_length=50)
    lastname = models.CharField("Фамилия", max_length=50)
    phonenumber = PhoneNumberField("Номер телефона", region="RU")
    address = models.CharField("Адрес", max_length=200)
    created_at = models.DateTimeField("Дата создания", auto_now_add=True)
    called_at = models.DateTimeField("Дата звонка", null=True, blank=True)
    delivered_at = models.DateTimeField("Дата доставки", null=True, blank=True)

    def total_price(self):
        return (
            self.items.aggregate(total=Sum(F("quantity") * F("fixed_price")))["total"]
            or 0
        )

    def get_available_restaurants(self):
        return (
            Restaurant.objects.filter(
                menu_items__product__in=self.items.values("product"),
                menu_items__availability=True,
            )
            .annotate(total_products=Count("menu_items__product", distinct=True))
            .filter(total_products=self.items.count())
            .distinct()
        )

    def get_restaurants_with_distances(self):
        if not self.latitude or not self.longitude:
            return []
        restaurants = []
        for restaurant in self.get_available_restaurants():
            if not restaurant.latitude or not restaurant.longitude:
                continue
            try:
                dist = calculate_distance(
                    (self.latitude, self.longitude),
                    (restaurant.latitude, restaurant.longitude),
                )
                restaurants.append({"restaurant": restaurant, "distance": dist})
            except Exception as e:
                logger.error(f"Ошибка расчета расстояния: {str(e)}")
        return sorted(restaurants, key=lambda x: x["distance"])

    def save(self, *args, **kwargs):

        if self.address and (not self.pk or self.address != self._get_old_address()):
            coords, _ = AddressCoordinates.objects.get_or_create(address=self.address)
            self.latitude = coords.latitude
            self.longitude = coords.longitude
        super().save(*args, **kwargs)

    def _get_old_address(self):
        if self.pk:
            return Order.objects.get(pk=self.pk).address
        return None

    class Meta:
        verbose_name = "заказ"
        verbose_name_plural = "заказы"
        ordering = ["-created_at"]

    def __str__(self):
        return f'Заказ №{self.id} от {self.created_at.strftime("%d-%m-%Y %H:%M")}'


class OrderItem(models.Model):
    order = models.ForeignKey(
        Order, on_delete=models.CASCADE, related_name="items", verbose_name="заказ"
    )
    product = models.ForeignKey(
        "Product",
        on_delete=models.CASCADE,
        related_name="order_items",
        verbose_name="товар",
    )
    quantity = models.IntegerField(
        "количество", default=1, validators=[MinValueValidator(1)]
    )

    fixed_price = models.DecimalField(
        verbose_name="фиксированная цена",
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0)],
        null=False,
        blank=False,
    )

    class Meta:
        verbose_name = "элемент заказа"
        verbose_name_plural = "элементы заказа"

    def __str__(self):
        return f"{self.product.name} x {self.quantity}"


class Restaurant(models.Model):
    name = models.CharField("название", max_length=50)
    address = models.CharField(
        "адрес",
        max_length=100,
        blank=True,
    )
    contact_phone = models.CharField(
        "контактный телефон",
        max_length=50,
        blank=True,
    )

    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)

    def save(self, *args, **kwargs):
        from geocoder.models import AddressCoordinates

        if self.address and (
            not self.pk or self.address != Restaurant.objects.get(pk=self.pk).address
        ):
            coords, _ = AddressCoordinates.objects.get_or_create(address=self.address)
            self.latitude = coords.latitude
            self.longitude = coords.longitude
        super().save(*args, **kwargs)

    class Meta:
        verbose_name = "ресторан"
        verbose_name_plural = "рестораны"

    def __str__(self):
        return self.name


class ProductCategory(models.Model):
    name = models.CharField("название", max_length=50)

    class Meta:
        verbose_name = "категория"
        verbose_name_plural = "категории"

    def __str__(self):
        return self.name


class ProductQuerySet(models.QuerySet):
    def available(self):
        products = RestaurantMenuItem.objects.filter(availability=True).values_list(
            "product"
        )
        return self.filter(pk__in=products)


class Product(models.Model):
    name = models.CharField("название", max_length=50)
    category = models.ForeignKey(
        ProductCategory,
        verbose_name="категория",
        related_name="products",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
    )
    price = models.DecimalField(
        "цена", max_digits=8, decimal_places=2, validators=[MinValueValidator(0)]
    )
    image = models.ImageField("картинка")
    special_status = models.BooleanField(
        "спец.предложение",
        default=False,
        db_index=True,
    )
    description = models.TextField(
        "описание",
        max_length=200,
        blank=True,
    )
    is_available = models.BooleanField(
        "Доступен для заказа", default=True, db_index=True
    )
    comment = models.TextField(null=True, blank=True)
    restaurant = models.ForeignKey(
        "Restaurant", on_delete=models.CASCADE, null=True, blank=True
    )

    PAYMENT_METHOD_CHOICES = [
        ("electronic", "Электронно"),
        ("cash", "Наличные"),
    ]
    payment_method = models.CharField(
        "Способ оплаты",
        max_length=20,
        choices=PAYMENT_METHOD_CHOICES,
        default="cash",
        db_index=True,
    )

    objects = ProductQuerySet.as_manager()

    class Meta:
        verbose_name = "товар"
        verbose_name_plural = "товары"

    def __str__(self):
        return self.name


class RestaurantMenuItem(models.Model):
    restaurant = models.ForeignKey(
        Restaurant,
        related_name="menu_items",
        verbose_name="ресторан",
        on_delete=models.CASCADE,
    )
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name="menu_items",
        verbose_name="продукт",
    )
    availability = models.BooleanField("в продаже", default=True, db_index=True)

    class Meta:
        verbose_name = "пункт меню ресторана"
        verbose_name_plural = "пункты меню ресторана"
        unique_together = [["restaurant", "product"]]

    def __str__(self):
        return f"{self.restaurant.name} - {self.product.name}"
