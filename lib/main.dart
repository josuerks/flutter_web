import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MaterialApp(
    home: PublicationsScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

const String host = "https://paris-4nys.onrender.com";

class PublicationsScreen extends StatefulWidget {
  @override
  _PublicationsScreenState createState() => _PublicationsScreenState();
}

class _PublicationsScreenState extends State<PublicationsScreen> {
  List publications = [];

  @override
  void initState() {
    super.initState();
    fetchPublications();
  }

  void fetchPublications() async {
    try {
      final response = await http.get(Uri.parse('$host/publications'));
      if (response.statusCode == 200) {
        setState(() {
          publications = json.decode(response.body);
        });
      }
    } catch (e) {
      print("Erreur: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Boutique")),
      body: publications.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: publications.length,
        itemBuilder: (context, index) {
          final item = publications[index];
          return Card(
            margin: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(
                  '$host/${item["image"]}',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    item['desc'] ?? '',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    "Prix : ${item["prix_fc"]} Fc / ${item["prix_usd"]} \$",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: ElevatedButton(
                    onPressed: () {
                      // Tu peux ajouter ici l'action pour acheter
                    },
                    child: Text("Acheter"),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
