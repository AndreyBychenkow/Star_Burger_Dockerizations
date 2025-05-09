from rest_framework import serializers
from phonenumber_field.serializerfields import PhoneNumberField
from .models import Order, OrderItem, Product


class OrderItemSerializer(serializers.ModelSerializer):
    product = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(),
        error_messages={'does_not_exist': 'Товар с ID {pk_value} не существует'}
    )
    quantity = serializers.IntegerField(
        min_value=1,
        max_value=20,
        error_messages={
            'min_value': 'Минимальное количество: 1',
            'max_value': 'Максимальное количество: 20'
        }
    )

    class Meta:
        model = OrderItem
        fields = ['product', 'quantity']


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(
        many=True,
        write_only=True
    )

    firstname = serializers.CharField(
        max_length=50,
        min_length=2,
        trim_whitespace=True
    )

    lastname = serializers.CharField(
        max_length=50,
        min_length=2,
        trim_whitespace=True
    )

    phonenumber = PhoneNumberField(
        error_messages={'invalid': 'Неверный формат номера телефона'}
    )

    address = serializers.CharField(
        max_length=200,
        min_length=10,
        trim_whitespace=True
    )

    class Meta:
        model = Order
        fields = ['id', 'firstname', 'lastname', 'phonenumber', 'address', 'items']
        read_only_fields = ['id']

    def validate_items(self, value):
        if not value:
            raise serializers.ValidationError("Заказ должен содержать хотя бы один товар")
        return value

    def create(self, validated_data):
        items_data = validated_data.pop('items')
        order = Order.objects.create(**validated_data)

        order_items = [
            OrderItem(
                order=order,
                product=item_data['product'],
                quantity=item_data['quantity'],
                fixed_price=item_data['product'].price
            )
            for item_data in items_data
        ]
        OrderItem.objects.bulk_create(order_items)

        return order
