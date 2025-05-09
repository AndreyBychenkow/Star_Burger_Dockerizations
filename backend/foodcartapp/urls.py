from django.urls import path

from .views import OrderCreateView, product_list_api, banners_list_api

urlpatterns = [
    path('products/', product_list_api),
    path('banners/', banners_list_api),
    path('order/', OrderCreateView.as_view(), name='order'),
]
