import requests

from django.conf import settings
from django.db import models

from django.utils import timezone
from datetime import timedelta

import logging

logger = logging.getLogger(__name__)


class AddressCoordinates(models.Model):
    address = models.TextField("Адрес места", max_length=200, unique=True)
    latitude = models.FloatField("Широта", null=True, blank=True)
    longitude = models.FloatField("Долгота", null=True, blank=True)
    updated_at = models.DateTimeField(
        "Дата/время обновления", auto_now=True, db_index=True
    )

    def is_fresh(self):
        return timezone.now() - self.updated_at < timedelta(days=30)

    CACHE_TTL = timezone.timedelta(days=30)

    class Meta:
        verbose_name = "координаты адреса"
        verbose_name_plural = "координаты адресов"
        indexes = [
            models.Index(fields=["address"]),
            models.Index(fields=["updated_at"]),
        ]

    @classmethod
    def get_or_create(cls, address):
        obj, created = cls.objects.get_or_create(address=address)
        if created or obj.requires_refresh():
            obj.update_from_api()
        return obj

    def requires_refresh(self):
        if not self.updated_at:
            return True
        return (timezone.now() - self.updated_at) > self.CACHE_TTL

    def update_from_api(self):
        try:
            response = requests.get(
                "https://geocode-maps.yandex.ru/1.x/",
                params={
                    "apikey": settings.YANDEX_GEOCODER_API_KEY,
                    "format": "json",
                    "geocode": self.address,
                },
                timeout=5,
            )
            response.raise_for_status()

            data = response.json()
            collection = data.get("response", {}).get("GeoObjectCollection", {})
            features = collection.get("featureMember", [])

            if features:
                point = features[0]["GeoObject"]["Point"]
                lon, lat = map(float, point["pos"].split())
                self.latitude = lat
                self.longitude = lon
            else:
                logger.warning(f"No coordinates found for address: {self.address}")
                self.latitude = None
                self.longitude = None
            self.save()
        except requests.exceptions.RequestException as e:
            logger.error(f"API request failed for {self.address}: {str(e)}")
            if not self.pk:
                self.delete()
            raise
        except Exception as e:
            logger.error(f"Ошибка обновления координат: {str(e)}")
        self.save()
        raise

    def __str__(self):
        return f"{self.address} ({self.latitude}, {self.longitude})"
