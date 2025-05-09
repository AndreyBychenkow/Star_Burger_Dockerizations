import logging
import requests

from geopy import distance
from foodcartapp.models import AddressCoordinates  # Импортируем модель

logger = logging.getLogger(__name__)


def get_coordinates(address):

    try:
        response = requests.get(f"https://api.example.com/geocode?address={address}")
        data = response.json()

        if (
            "response" in data
            and data["response"]["GeoObjectCollection"]["featureMember"]
        ):
            point = data["response"]["GeoObjectCollection"]["featureMember"][0][
                "GeoObject"
            ]["Point"]["pos"]
            longitude, latitude = map(float, point.split())

            AddressCoordinates.objects.update_or_create(
                address=address, defaults={"latitude": latitude, "longitude": longitude}
            )
            return (latitude, longitude)
        else:
            return None
    except Exception as e:
        logger.error(f"Error fetching coordinates: {str(e)}")
        return None


def calculate_distance(point_a, point_b):
    if not point_a or not point_b:
        return None
    try:
        return round(distance.distance(point_a, point_b).km, 1)
    except Exception as e:
        logger.error(f"Distance calculation error: {str(e)}")
        return None
