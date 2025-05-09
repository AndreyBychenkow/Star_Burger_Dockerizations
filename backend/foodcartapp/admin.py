from django.contrib import admin
from django.shortcuts import reverse, redirect

from django.templatetags.static import static
from django.utils.html import format_html
from django.utils.http import url_has_allowed_host_and_scheme

from .models import Product
from .models import ProductCategory

from .models import Restaurant
from .models import RestaurantMenuItem
from .models import Order, OrderItem

from django import forms


class RestaurantMenuItemInline(admin.TabularInline):
    model = RestaurantMenuItem
    extra = 0


@admin.register(Restaurant)
class RestaurantAdmin(admin.ModelAdmin):
    search_fields = [
        "name",
        "address",
        "contact_phone",
    ]
    list_display = [
        "name",
        "address",
        "contact_phone",
    ]
    inlines = [RestaurantMenuItemInline]


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = [
        "get_image_list_preview",
        "name",
        "category",
        "price",
    ]
    list_display_links = [
        "name",
    ]
    list_filter = [
        "category",
    ]
    search_fields = [
        # FIXME SQLite can not convert letter case for cyrillic words properly, so search will be buggy.
        # Migration to PostgreSQL is necessary
        "name",
        "category__name",
    ]

    inlines = [RestaurantMenuItemInline]

    fieldsets = (
        (
            "Общее",
            {
                "fields": [
                    "name",
                    "category",
                    "image",
                    "get_image_preview",
                    "price",
                    "comment",
                    "payment_method",
                    "restaurant",
                ]
            },
        ),
        (
            "Подробно",
            {
                "fields": [
                    "special_status",
                    "description",
                ],
                "classes": ["wide"],
            },
        ),
    )

    readonly_fields = [
        "get_image_preview",
    ]

    class Media:
        css = {"all": (static("admin/foodcartapp.css"))}

    def get_image_preview(self, obj):
        if not obj.image:
            return "выберите картинку"
        return format_html(
            '<img src="{url}" style="max-height: 200px;"/>', url=obj.image.url
        )

    get_image_preview.short_description = "превью"

    def get_image_list_preview(self, obj):
        if not obj.image or not obj.id:
            return "нет картинки"
        edit_url = reverse("admin:foodcartapp_product_change", args=(obj.id,))
        return format_html(
            '<a href="{edit_url}"><img src="{src}" style="max-height: 50px;"/></a>',
            edit_url=edit_url,
            src=obj.image.url,
        )

    get_image_list_preview.short_description = "превью"


class OrderItemForm(forms.ModelForm):
    class Meta:
        model = OrderItem
        fields = ["product", "quantity", "fixed_price"]

    def clean_fixed_price(self):
        fixed_price = self.cleaned_data.get("fixed_price")
        product = self.cleaned_data.get("product")

        if product is not None:

            if isinstance(product, Product):

                if fixed_price is None or fixed_price <= 0:
                    fixed_price = product.price
            else:
                raise forms.ValidationError("Invalid product selected.")
        if fixed_price < 0:
            raise forms.ValidationError("Fixed price cannot be negative.")
        return fixed_price


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    form = OrderItemForm
    extra = 1
    fields = ["product", "quantity", "fixed_price"]


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    def formatted_date(self, obj):
        return obj.created_at.strftime("%d-%m-%Y %H:%M")

    formatted_date.short_description = "Дата создания"
    inlines = [OrderItemInline]
    list_display = [
        "id",
        "firstname",
        "lastname",
        "phonenumber",
        "address",
        "formatted_date",
        "status",
        "comment",
        "payment_method",
        "restaurant",
    ]
    autocomplete_fields = ["restaurant"]
    search_fields = ["firstname", "lastname", "phonenumber", "address"]

    list_filter = ["created_at", "status", "restaurant"]

    ordering = ["-created_at"]

    readonly_fields = [
        "created_at",
    ]

    def response_change(self, request, obj):
        next_url = request.GET.get("next")
        if next_url and url_has_allowed_host_and_scheme(next_url, allowed_hosts=None):
            return redirect(next_url)
        return super().response_change(request, obj)


@admin.register(ProductCategory)
class ProductAdmin(admin.ModelAdmin):
    pass
