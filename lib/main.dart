import 'package:flutter/material.dart';
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
  Future<List<Product>> futureProducts;

  @override
  void initState() {
    super.initState();
    futureProducts = searchProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome to Sunrise'),
      ),
      backgroundColor: Colors.white,
      body: FutureBuilder<List<Product>>(
          future: futureProducts,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 30.0,
                  crossAxisSpacing: 4.0,
                  padding: EdgeInsets.all(10.0),
                  children: snapshot.data
                      .map<Widget>(
                          (Product product) => ProductItem(product: product))
                      .toList());
            } else if (snapshot.hasError) {
              return Text("${snapshot.error}");
            }

            return Center(child: CircularProgressIndicator());
          }),
    );
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
          Expanded(child: Image.network(product.imageUrl)),
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

Future<List<Product>> searchProducts() async {
  final response = await ctApi.get(ProjectKey, '/product-projections/search');

  if (response.statusCode != 200) {
    log(response.body);
    throw Exception('failed to fetch products');
  }

  return parseProducts(json.decode(response.body));
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
