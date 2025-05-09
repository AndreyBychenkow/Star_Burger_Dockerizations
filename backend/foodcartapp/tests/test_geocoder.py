from django.test import TestCase
from unittest.mock import patch
from geocoder.models import AddressCoordinates
from foodcartapp.utils import get_coordinates
from django.utils import timezone


class GeocoderUtilsTestCase(TestCase):

    def setUp(self):
        self.test_address = "Москва, Красная площадь, 1"
        self.mock_response = {
            "response": {
                "GeoObjectCollection": {
                    "featureMember": [
                        {"GeoObject": {"Point": {"pos": "37.620795 55.753930"}}}
                    ]
                }
            }
        }

    @patch("requests.get")
    def test_get_coordinates_saves_to_db(self, mock_get):
        """Проверка, что координаты сохраняются в БД"""
        mock_get.return_value.json.return_value = self.mock_response

        coords = get_coordinates(self.test_address)

        # Проверяем, что координаты возвращаются правильно

        self.assertEqual(coords, (55.753930, 37.620795))

        # Проверяем, что запись создана в БД

        db_record = AddressCoordinates.objects.get(address=self.test_address)
        self.assertEqual(
            (db_record.latitude, db_record.longitude), (55.753930, 37.620795)
        )

    @patch("requests.get")
    def test_get_coordinates_updates_existing_record(self, mock_get):
        """Проверка, что существующая запись обновляется при необходимости"""
        old_record = AddressCoordinates.objects.create(
            address=self.test_address,
            latitude=0.0,
            longitude=0.0,
            updated_at=timezone.now() - timezone.timedelta(days=31),  # Устарела
        )

        mock_get.return_value.json.return_value = self.mock_response

        coords = get_coordinates(self.test_address)

        # Проверяем, что координаты возвращаются правильно

        self.assertEqual(coords, (55.753930, 37.620795))

        # Проверяем, что запись была обновлена

        updated_record = AddressCoordinates.objects.get(address=self.test_address)
        self.assertNotEqual(updated_record.latitude, old_record.latitude)
        self.assertNotEqual(updated_record.longitude, old_record.longitude)

    @patch("requests.get")
    def test_get_coordinates_invalid_address(self, mock_get):
        """Проверка, что неверный адрес возвращает None"""
        mock_get.return_value.json.return_value = {}

        coords = get_coordinates("invalid_address_123")
        self.assertIsNone(coords)  # Проверяем, что вернулось None
        self.assertFalse(
            AddressCoordinates.objects.filter(address="invalid_address_123").exists()
        )
