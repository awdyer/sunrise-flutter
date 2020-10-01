import 'package:flutter/material.dart';
import 'package:transparent_image/transparent_image.dart';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'config.dart' as config;
import 'ct.dart' as ct;

const ProjectKey = config.CtProjectKey;
const CountryCode = 'DE';
const CurrencyCode = 'EUR';

final ctApi = ct.Api(
  clientId: config.CtClientId,
  clientSecret: config.CtClientSecret,
  apiUrl: ct.GcpEuApiUrl,
  authUrl: ct.GcpEuAuthUrl,
);

void main() => runApp(SunriseApp());

class SunriseApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CT Sunrise',
      home: ProductPage(),
    );
  }
}

class ProductPage extends StatefulWidget {
  ProductPage({Key key}) : super(key: key);

  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _products = <Product>[];
  var _isLoading = true;
  var _hasMore = true;
  final _productSearcher = ProductSearcher();

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _hasMore = true;
    _loadMoreProducts();
  }

  void _loadMoreProducts() async {
    if (!_hasMore) {
      return;
    }

    _isLoading = true;
    final newProducts = await _productSearcher.searchProducts();
    if (newProducts.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _products.addAll(newProducts);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Welcome to Sunrise'),
        ),
        backgroundColor: Colors.white,
        body: GridView.builder(
            itemCount: _hasMore ? _products.length + 1 : _products.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 30.0,
              crossAxisSpacing: 4.0,
            ),
            padding: EdgeInsets.all(10.0),
            itemBuilder: (BuildContext context, int index) {
              // print('GridView.builder is building index $index');
              if (index >= _products.length) {
                if (!_isLoading) {
                  _loadMoreProducts();
                }
                return Center(
                  child: SizedBox(
                    child: CircularProgressIndicator(),
                    height: 24,
                    width: 24,
                  ),
                );
              }
              return ProductItem(product: _products[index]);
            }));
  }
}

class ProductItem extends StatelessWidget {
  ProductItem({this.product}) : super(key: ObjectKey(product));

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.topLeft,
      child: Column(
        children: [
          Expanded(
              child: FadeInImage(
            fadeInDuration: Duration(milliseconds: 200),
            placeholder: MemoryImage(kTransparentImage),
            image: NetworkImage(product.imageUrl),
            imageErrorBuilder: (BuildContext context, Object exception,
                StackTrace stackTrace) {
              return Container(
                width: 100.0,
                height: 100.0,
                child: Text('image not found'),
              );
            },
          )),
          SizedBox(height: 10),
          Text(product.name),
          SizedBox(height: 5),
          Text(product.price,
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              )),
        ],
      ),
    );
  }
}

class Product {
  Product({this.name, this.price, this.imageUrl});

  final String name;
  final String price;
  final String imageUrl;
}

class ProductSearcher {
  var _limit = 20;
  var _currentOffset = 0;
  var _hasMore = true;

  Future<List<Product>> searchProducts() async {
    if (!_hasMore) {
      return <Product>[];
    }

    print('limit: $_limit, offset: $_currentOffset');
    final response = await ctApi.get(ProjectKey, '/product-projections/search', queryParameters: {
      'limit': _limit.toString(),
      'offset': _currentOffset.toString(),
    });

    if (response.statusCode != 200) {
      log(response.body);
      throw Exception('failed to fetch products');
    }

    final results = json.decode(response.body);
    if (results['count'] < _limit) {
      _hasMore = false;
    }
    _currentOffset += _limit;

    return parseProducts(results);
  }
}

List<Product> parseProducts(Map<String, dynamic> json) {
  return List<Product>.from(json['results'].map((result) {
    final String name = result['name']['en'];
    final masterVariant = result['masterVariant'];
    final String imageUrl = masterVariant['images'][0]['url'];
    final String price = getPrice(masterVariant['prices']);
    return Product(name: name, price: price, imageUrl: imageUrl);
  }));
}

String getPrice(List<dynamic> prices) {
  for (final price in prices) {
    if (price['country'] == CountryCode &&
        price['value']['currencyCode'] == CurrencyCode &&
        price['customerGroup'] == null &&
        price['channel'] == null) {
      return formatPrice(price);
    }
  }

  // return first price if nothing matched
  return formatPrice(prices[0]);
}

String formatPrice(Map<String, dynamic> price) {
  final value = price['value'];
  final double amount =
      value['centAmount'] / math.pow(10, value['fractionDigits']);
  final amountStr = amount.toStringAsFixed(value['fractionDigits']);
  return '€$amountStr';
}
