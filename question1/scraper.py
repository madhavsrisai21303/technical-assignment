#!/usr/bin/env python3
"""Extract product names and selling prices from MDComputers search results."""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from urllib.parse import quote_plus

import requests
from bs4 import BeautifulSoup
from requests import RequestException

BASE_URL = "https://mdcomputers.in"
SEARCH_PATH = "/index.php?route=product/search&search="
USER_AGENT = "technical-assignment-scraper/1.0"


@dataclass(frozen=True)
class Product:
    """A product displayed in search results."""

    name: str
    price: str


def build_search_url(search_term: str) -> str:
    """Build the MDComputers search URL for a user-supplied term."""
    return f"{BASE_URL}{SEARCH_PATH}{quote_plus(search_term.strip())}"


def _text(element) -> str:
    return " ".join(element.get_text(" ", strip=True).split()) if element else ""


def parse_products(html: str) -> list[Product]:
    """Parse product cards, using a small set of resilient selector fallbacks."""
    soup = BeautifulSoup(html, "html.parser")
    cards = soup.select(".product-layout, .product-thumb, .product-grid-item")
    products: list[Product] = []

    for card in cards:
        name_element = card.select_one(".caption h4 a, .caption .name a, h4 a, .product-name a")
        price_element = card.select_one(".price-new, .price, .product-price")
        name = _text(name_element)
        price = _text(price_element)
        if name and price:
            products.append(Product(name=name, price=price))

    # Fallback for a markup variation where product cards are not classed consistently.
    if not products:
        for link in soup.select('a[href*="/product/"]'):
            name = _text(link)
            container = link.find_parent(class_=lambda value: value and "product" in " ".join(value) if isinstance(value, list) else value and "product" in value)
            price_element = container.select_one(".price-new, .price, .product-price") if container else None
            price = _text(price_element)
            if name and price:
                products.append(Product(name=name, price=price))

    # Preserve page order while removing duplicate cards often created by carousels.
    unique_products: list[Product] = []
    seen: set[tuple[str, str]] = set()
    for product in products:
        key = (product.name, product.price)
        if key not in seen:
            seen.add(key)
            unique_products.append(product)
    return unique_products


def fetch_products(search_term: str, timeout: int = 20) -> list[Product]:
    """Fetch and parse products for a search term."""
    url = build_search_url(search_term)
    response = requests.get(
        url,
        headers={"User-Agent": USER_AGENT},
        timeout=timeout,
    )
    response.raise_for_status()
    return parse_products(response.text)


def print_products(search_term: str, products: list[Product]) -> None:
    """Print results in a simple table."""
    print(f"Search results for: {search_term}")
    print("=" * 80)
    if not products:
        print("No products found.")
        return
    print(f"{'#':>3}  {'Product name':<60}  Selling price")
    print("-" * 80)
    for number, product in enumerate(products, start=1):
        print(f"{number:>3}  {product.name[:60]:<60}  {product.price}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("search_term", nargs="?", help="product search term")
    args = parser.parse_args()
    search_term = args.search_term or input("Enter search term: ").strip()
    if not search_term:
        print("Error: a search term is required.", file=sys.stderr)
        return 2

    try:
        products = fetch_products(search_term)
    except RequestException as error:
        print(f"Error: unable to retrieve search results ({error}).", file=sys.stderr)
        return 1
    except ValueError as error:
        print(f"Error: unable to parse search results ({error}).", file=sys.stderr)
        return 1

    print_products(search_term, products)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
