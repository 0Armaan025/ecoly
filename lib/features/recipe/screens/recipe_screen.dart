import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_synergy/constants/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../common/drawer/stylish_drawer.dart';

class RecipeScreen extends StatefulWidget {
  @override
  _RecipeScreenState createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _ingredients = [];
  List<Map<String, dynamic>> _recipes = [];
  bool _isVeg = false;

  void _addIngredient() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _ingredients.add(_controller.text);
        _controller.clear();
      });
    }
  }

  void _searchRecipes() async {
    // Replace with your own API key and endpoint
    const String apiKey = '8063cdcba8ca4047a57db98abb4844e2';
    const String endpoint =
        'https://api.spoonacular.com/recipes/findByIngredients';

    // Build the query parameters
    final String ingredients = _ingredients.join(',');
    const int number = 10; // Number of results to return
    final Map<String, String> queryParams = {
      'apiKey': apiKey,
      'ingredients': ingredients,
      'number': number.toString(),
      'diet': _isVeg ? 'vegetarian' : '',
    };
    final Uri uri = Uri.parse(endpoint).replace(queryParameters: queryParams);

    // Send the request
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      // Parse the response
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        _recipes = data.map((recipe) {
          return {
            'title': recipe['title'],
            'image': recipe['image'],
            'usedIngredients': recipe['usedIngredients']
                .map((ingredient) => ingredient['name'])
                .toList(),
            'missedIngredients': recipe['missedIngredients']
                .map((ingredient) => ingredient['name'])
                .toList(),
          };
        }).toList();
      });
    } else {
      // Handle error
      if (kDebugMode) {
        print('Error: ${response.statusCode}');
      }
    }
  }

  void _shareOnTwitter(String recipeTitle) async {
    final String tweetText =
        'Check out this delicious recipe: ( $recipeTitle! ) that I just made using Ecoly.\n\n$appTagLine\n\n\nSent through: Ecoly by Armaan';

    try {
      await Share.share(tweetText);
      final userId = firebaseAuth.currentUser?.uid ?? '';
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);

      var firestoreData = await userRef.get();

      String money = firestoreData.get('ecoCurrency') ?? '0';

      try {
        int parsedMoney = int.parse(money);
        await userRef.update({
          'ecoCurrency': (parsedMoney + 50).toString(),
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("yay! congrats on 50 more points! 🎉"),
        ));
      } catch (error) {}
    } catch (e) {
      if (kDebugMode) {
        print("Error sharing on Twitter: $e");
      }
    }
  }

  void _shareAllRecipesOnTwitter() async {
    for (final recipe in _recipes) {
      _shareOnTwitter(recipe['title']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Finder'),
      ),
      drawer: buildstylishDrawer(context),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter an ingredient',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addIngredient,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Vegetarian'),
              Switch(
                value: _isVeg,
                onChanged: (value) {
                  setState(() {
                    _isVeg = value;
                  });
                },
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _ingredients.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_ingredients[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _ingredients.removeAt(index);
                      });
                    },
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: _searchRecipes,
            child: const Text('Search for recipes'),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 8.0,
                crossAxisSpacing: 8.0,
              ),
              itemCount: _recipes.length,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 4.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 80.0,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            fit: BoxFit.cover,
                            image: NetworkImage(_recipes[index]['image']),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: InkWell(
                          onTap: () async {
                            final String query =
                                Uri.encodeComponent(_recipes[index]['title']);
                            final String url =
                                'https://www.google.com/search?q=$query';
                            if (await canLaunch(url)) {
                              await launch(url);
                            } else {
                              if (kDebugMode) {
                                print("Could not launch $url");
                              }
                            }
                          },
                          child: Text(
                            _recipes[index]['title'],
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Used Ingredients: ${_recipes[index]['usedIngredients'].join(', ')}',
                        style: const TextStyle(fontSize: 8.2),
                      ),
                      InkWell(
                        onTap: () => _shareOnTwitter(_recipes[index]['title']),
                        child: const Icon(
                          Icons.share,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _recipes.clear();
                _ingredients.clear();
              });
            },
            tooltip: 'Clear Search',
            child: const Icon(Icons.clear),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
              onPressed: _shareAllRecipesOnTwitter,
              tooltip: 'Share All Recipes on Twitter',
              child: const Icon(Icons.share)),
        ],
      ),
    );
  }
}
