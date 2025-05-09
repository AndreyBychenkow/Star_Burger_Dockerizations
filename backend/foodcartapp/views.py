from rest_framework import generics
from rest_framework.response import Response
from rest_framework import status

from django.http import JsonResponse
from django.templatetags.static import static

from .models import Product, Order
from .serializers import OrderSerializer


class OrderCreateView(generics.CreateAPIView):
    serializer_class = OrderSerializer
    queryset = Order.objects.all()

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


def banners_list_api(request):
    return JsonResponse([
        {
            "title": "Burger",
            "src": static("burger.jpg"),
            "text": "Tasty Burger at your door step",
        },
        {
            "title": "Spices",
            "src": static("food.jpg"),
            "text": "All Cuisines",
        },
        {
            "title": "New York",
            "src": static("tasty.jpg"),
            "text": "Food is incomplete without a tasty dessert",
        },
    ], safe=False, json_dumps_params={"ensure_ascii": False, "indent": 4})


def product_list_api(request):
    products = Product.objects.select_related("category").available()
    return JsonResponse([
        {
            "id": product.id,
            "name": product.name,
            "price": product.price,
            "special_status": product.special_status,
            "description": product.description,
            "category": {
                "id": product.category.id,
                "name": product.category.name,
            } if product.category else None,
            "image": product.image.url,
            "restaurant": {
                "id": product.id,
                "name": product.name,
            }
        } for product in products
    ], safe=False, json_dumps_params={"ensure_ascii": False, "indent": 4})
