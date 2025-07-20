import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late IO.Socket socket;
  List<String> publicites = [];
  String status = "";
  final TextEditingController userController = TextEditingController();
  final TextEditingController matchController = TextEditingController();
  final TextEditingController choixController = TextEditingController();

  final String serverUrl = "https://ton-serveur.herokuapp.com"; // Change ici

  @override
  void initState() {
    super.initState();
    // Connexion socket
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();

    socket.onConnect((_) {
      print("Connecté au serveur Socket.IO");
      setState(() {
        status = "Connecté";
      });
    });

    socket.on("pub", (data) {
      print("Pub reçue: $data");
      setState(() {
        publicites.add(data.toString());
      });
    });

    socket.onDisconnect((_) {
      print("Déconnecté");
      setState(() {
        status = "Déconnecté";
      });
    });
  }

  // Envoyer un pari (POST)
  Future<void> envoyerPari() async {
    final user = userController.text.trim();
    final matchId = matchController.text.trim();
    final choix = choixController.text.trim();

    if (user.isEmpty || matchId.isEmpty || choix.isEmpty) {
      setState(() {
        status = "Remplis tous les champs";
      });
      return;
    }

    final response = await http.post(
      Uri.parse("$serverUrl/parier"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"user": user, "match_id": matchId, "choix": choix}),
    );

    if (response.statusCode == 200) {
      setState(() {
        status = "Pari envoyé avec succès !";
      });
    } else {
      final error = jsonDecode(response.body)['error'] ?? "Erreur inconnue";
      setState(() {
        status = "Erreur: $error";
      });
    }
  }

  // Récupérer résultats (GET)
  Future<void> recupererResultats() async {
    final user = userController.text.trim();
    if (user.isEmpty) {
      setState(() {
        status = "Entrez votre nom d'utilisateur pour voir résultats";
      });
      return;
    }

    final response = await http.get(Uri.parse("$serverUrl/get_resultat/$user"));

    if (response.statusCode == 200) {
      final List resultats = jsonDecode(response.body);
      String message = "Résultats:\n";
      for (var r in resultats) {
        message +=
        "${r['match']} - Votre choix: ${r['choix']} - Gagnant: ${r['gagnant']} - Vous avez ${r['résultat']}\n";
      }
      setState(() {
        status = message;
      });
    } else {
      setState(() {
        status = "Erreur lors de la récupération des résultats";
      });
    }
  }

  @override
  void dispose() {
    socket.dispose();
    userController.dispose();
    matchController.dispose();
    choixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Paris en direct",
      home: Scaffold(
        appBar: AppBar(
          title: Text("Paris en direct"),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text("Statut socket: $status"),
                SizedBox(height: 10),
                Text("Publicités reçues :"),
                ...publicites.map((p) => Text("- $p")),
                Divider(),

                TextField(
                  controller: userController,
                  decoration: InputDecoration(labelText: "Votre nom d'utilisateur"),
                ),
                TextField(
                  controller: matchController,
                  decoration: InputDecoration(labelText: "ID du match"),
                ),
                TextField(
                  controller: choixController,
                  decoration: InputDecoration(labelText: "Votre choix"),
                ),
                ElevatedButton(
                  onPressed: envoyerPari,
                  child: Text("Envoyer pari"),
                ),
                ElevatedButton(
                  onPressed: recupererResultats,
                  child: Text("Voir mes résultats"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
