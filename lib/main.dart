import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() => runApp(ParisApp());

class ParisApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paris Foot',
      theme: ThemeData(primarySwatch: Colors.green),
      home: RegisterPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  Future<void> _register() async {
    final rv = await http.post(
      Uri.parse('https://paris-4nys.onrender.com/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nom': _nameCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text.trim()) ?? 0,
      }),
    );
    final data = jsonDecode(rv.body);
    final msg = data['message'] ?? data['error'] ?? 'Erreur';
    if (rv.statusCode == 200 || rv.statusCode == 201) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MatchListPage(user: _nameCtrl.text.trim())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Inscription')),
    body: Padding(
      padding: EdgeInsets.all(16),
      child: Column(children: [
        TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Nom')),
        TextField(
            controller: _ageCtrl,
            decoration: InputDecoration(labelText: 'Âge'),
            keyboardType: TextInputType.number),
        SizedBox(height: 20),
        ElevatedButton(onPressed: _register, child: Text('S’inscrire')),
      ]),
    ),
  );
}

class MatchListPage extends StatefulWidget {
  final String user;
  MatchListPage({required this.user});
  @override
  _MatchListPageState createState() => _MatchListPageState();
}

class _MatchListPageState extends State<MatchListPage> {
  final String server = 'https://paris-4nys.onrender.com';
  List<dynamic> matchs = [];
  List<String> pubs = [];
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _fetchMatchs();
    _setupSocket();
  }

  void _fetchMatchs() async {
    final res = await http.get(Uri.parse('$server/get_matchs'));
    if (res.statusCode == 200 && mounted) {
      setState(() => matchs = jsonDecode(res.body));
    }
  }

  void _setupSocket() {
    socket = IO.io(
      server,
      IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    socket.connect();
    socket.on('connect', (_) => print('🟢 Connecté'));
    socket.on('new_match', (data) {
      if (mounted) setState(() => matchs.add(data));
    });
    socket.on('pub', (data) {
      if (mounted) {
        setState(() {
          pubs.insert(0, data.toString());
          if (pubs.length > 5) pubs.removeLast();
        });
      }
    });
  }

  void _openPage(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(
      title: Text('Matchs - ${widget.user}'),
      actions: [
        IconButton(icon: Icon(Icons.shopping_bag), onPressed: () => _openPage(BoutiquePage(user: widget.user))),
        IconButton(icon: Icon(Icons.receipt), onPressed: () => _openPage(RecusPage(user: widget.user))),
        IconButton(icon: Icon(Icons.account_balance_wallet), onPressed: () => _openPage(SoldePage(user: widget.user))),
        IconButton(icon: Icon(Icons.attach_money), onPressed: () => _openPage(DepotPage(user: widget.user))),
        IconButton(icon: Icon(Icons.list_alt), onPressed: () => _openPage(ResultatPage(user: widget.user))),
      ],
    ),
    body: Column(
      children: [
        if (pubs.isNotEmpty)
          Container(
            height: 40,
            color: Colors.yellow[100],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: pubs.length,
              itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8), child: Chip(label: Text('📢 ${pubs[i]}'))),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: matchs.length,
            itemBuilder: (_, i) {
              final m = matchs[i];
              return ListTile(
                title: Text('${m['equipe1']} vs ${m['equipe2']}'),
                trailing: ElevatedButton(
                  child: Text('Parier'),
                  onPressed: () => Navigator.push(
                      ctx, MaterialPageRoute(builder: (_) => ParierPage(user: widget.user, match: m))),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class ParierPage extends StatefulWidget {
  final String user;
  final Map match;
  ParierPage({required this.user, required this.match});
  @override
  _ParierPageState createState() => _ParierPageState();
}

class _ParierPageState extends State<ParierPage> {
  String choix = '';
  String devise = 'usd';
  final _ctrl = TextEditingController();

  void _send() async {
    final montant = int.tryParse(_ctrl.text.trim()) ?? 0;
    if (montant <= 0 || choix.isEmpty) return;
    final res = await http.post(
      Uri.parse('https://paris-4nys.onrender.com/parier'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user': widget.user,
        'match_id': widget.match['id'],
        'choix': choix,
        'devise': devise,
        'montant': montant,
      }),
    );
    final d = jsonDecode(res.body);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(d['error'] ?? 'Pari effectué avec succès')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('${widget.match['equipe1']} vs ${widget.match['equipe2']}')),
    body: Padding(
      padding: EdgeInsets.all(16),
      child: Column(children: [
        TextField(
            controller: _ctrl,
            decoration: InputDecoration(labelText: 'Montant'),
            keyboardType: TextInputType.number),
        DropdownButton<String>(
          value: devise,
          items: ['usd', 'fc']
              .map((d) => DropdownMenuItem(value: d, child: Text(d.toUpperCase())))
              .toList(),
          onChanged: (v) => setState(() => devise = v!),
        ),
        SizedBox(height: 10),
        ElevatedButton(
            onPressed: () => setState(() => choix = widget.match['equipe1']),
            child: Text(widget.match['equipe1'])),
        ElevatedButton(onPressed: () => setState(() => choix = 'Nul'), child: Text('Nul')),
        ElevatedButton(
            onPressed: () => setState(() => choix = widget.match['equipe2']),
            child: Text(widget.match['equipe2'])),
        SizedBox(height: 20),
        ElevatedButton(onPressed: _send, child: Text('Valider pari')),
      ]),
    ),
  );
}

class SoldePage extends StatefulWidget {
  final String user;
  SoldePage({required this.user});
  @override
  _SoldePageState createState() => _SoldePageState();
}

class _SoldePageState extends State<SoldePage> {
  int fc = 0, usd = 0;
  void _fetch() async {
    final res = await http.get(Uri.parse('https://paris-4nys.onrender.com/balance/${widget.user}'));
    if (res.statusCode == 200 && mounted) {
      final d = jsonDecode(res.body);
      setState(() {
        fc = d['fc'] is int ? d['fc'] : int.tryParse(d['fc'].toString()) ?? 0;
        usd = d['usd'] is int ? d['usd'] : int.tryParse(d['usd'].toString()) ?? 0;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Mon compte')),
    body: Center(
        child: Text('FC: $fc\nUSD: $usd',
            style: TextStyle(fontSize: 22), textAlign: TextAlign.center)),
  );
}

class DepotPage extends StatefulWidget {
  final String user;
  DepotPage({required this.user});
  @override
  _DepotPageState createState() => _DepotPageState();
}

class _DepotPageState extends State<DepotPage> {
  final _fcCtrl = TextEditingController(text: '0');
  final _usdCtrl = TextEditingController(text: '0');
  String msg = '';

  Future<void> _envoyer() async {
    final fc = int.tryParse(_fcCtrl.text.trim()) ?? 0;
    final usd = int.tryParse(_usdCtrl.text.trim()) ?? 0;
    final res = await http.post(
      Uri.parse('https://paris-4nys.onrender.com/deposit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nom': widget.user, 'fc': fc, 'usd': usd}),
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      setState(() {
        msg = '✅ Dépôt effectué';
        _fcCtrl.text = _usdCtrl.text = '0';
      });
    } else {
      setState(() => msg = 'Erreur dépôt');
    }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Faire un dépôt')),
    body: Padding(
      padding: EdgeInsets.all(16),
      child: Column(children: [
        TextField(
            controller: _fcCtrl,
            decoration: InputDecoration(labelText: 'Montant FC'),
            keyboardType: TextInputType.number),
        TextField(
            controller: _usdCtrl,
            decoration: InputDecoration(labelText: 'Montant USD'),
            keyboardType: TextInputType.number),
        SizedBox(height: 20),
        ElevatedButton(onPressed: _envoyer, child: Text('Envoyer dépôt')),
        if (msg.isNotEmpty) SizedBox(height: 10),
        if (msg.isNotEmpty)
          Text(msg, style: TextStyle(color: msg.contains('✅') ? Colors.green : Colors.red)),
      ]),
    ),
  );
}

class BoutiquePage extends StatefulWidget {
  final String user;
  BoutiquePage({required this.user});
  @override
  _BoutiquePageState createState() => _BoutiquePageState();
}

class _BoutiquePageState extends State<BoutiquePage> {
  List<dynamic> arts = [];

  Future<void> _fetch() async {
    final res = await http.get(Uri.parse('https://paris-4nys.onrender.com/get_articles'));
    if (res.statusCode == 200 && mounted) {
      setState(() => arts = jsonDecode(res.body));
    }
  }

  void _acheter(Map a) async {
    String? dev = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Choisir une devise'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'usd'), child: Text('${a['prix_usd']} USD')),
          TextButton(onPressed: () => Navigator.pop(context, 'fc'), child: Text('${a['prix_fc']} FC')),
        ],
      ),
    );
    if (dev != null) {
      final res = await http.post(
        Uri.parse('https://paris-4nys.onrender.com/acheter'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user': widget.user, 'article_id': a['id'], 'devise': dev}),
      );
      final d = jsonDecode(res.body);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(d['message'] ?? d['error'] ?? 'Erreur inconnue')));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Boutique')),
    body: ListView.builder(
      itemCount: arts.length,
      itemBuilder: (_, i) {
        final a = arts[i];
        return Card(
          margin: EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (a['image'] != null)
              Image.network(a['image'], height: 180, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(children: [
                Text(a['description'] ?? 'Sans description', style: TextStyle(fontSize: 18)),
                Text('USD: ${a['prix_usd']}   FC: ${a['prix_fc']}',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
            Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(onPressed: () => _acheter(a), child: Text('Acheter'))),
          ]),
        );
      },
    ),
  );
}

class ResultatPage extends StatefulWidget {
  final String user;
  ResultatPage({required this.user});
  @override
  _ResultatPageState createState() => _ResultatPageState();
}

class _ResultatPageState extends State<ResultatPage> {
  List<dynamic> resu = [];
  Future<void> _fetch() async {
    final rv = await http.get(Uri.parse('https://paris-4nys.onrender.com/get_resultat/${widget.user}'));
    if (rv.statusCode == 200 && mounted) {
      setState(() => resu = jsonDecode(rv.body));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Mes Résultats')),
    body: ListView.builder(
      itemCount: resu.length,
      itemBuilder: (_, i) {
        final r = resu[i];
        final won = r['résultat'] == 'gagné';
        return ListTile(
          leading: Icon(won ? Icons.check_circle : Icons.cancel, color: won ? Colors.green : Colors.red),
          title: Text(r['match'] ?? 'Match inconnu'),
          subtitle: Text(
              'Choix: ${r['choix'] ?? '?'} - Mise: ${r['mise'] ?? 0} ${(r['devise'] ?? '').toString().toUpperCase()}'),
        );
      },
    ),
  );
}

class RecusPage extends StatefulWidget {
  final String user;
  RecusPage({required this.user});
  @override
  _RecusPageState createState() => _RecusPageState();
}

class _RecusPageState extends State<RecusPage> {
  List<dynamic> rcs = [];
  Future<void> _fetch() async {
    final r = await http.get(Uri.parse('https://paris-4nys.onrender.com/get_recus?user=${widget.user}'));
    if (r.statusCode == 200 && mounted) {
      setState(() => rcs = jsonDecode(r.body));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Mes Reçus')),
    body: ListView.builder(
      itemCount: rcs.length,
      itemBuilder: (_, i) {
        final r = rcs[i];
        final article = r['article'];
        String imageUrl = '';
        String description = '';
        if (article is Map) {
          imageUrl = article['image']?.toString() ?? '';
          description = article['description']?.toString() ??
              article['id']?.toString() ??
              r['article_id']?.toString() ??
              '';
        }
        final prix = r['prix']?.toString() ?? '';
        final devise = r['devise']?.toString().toUpperCase() ?? '';
        String dateStr;
        try {
          final ts = r['timestamp'];
          final tsInt = ts is int ? ts : int.tryParse(ts.toString()) ?? 0;
          dateStr =
              DateTime.fromMillisecondsSinceEpoch(tsInt * 1000).toLocal().toString();
        } catch (_) {
          dateStr = 'Date invalide';
        }
        return Card(
          margin: EdgeInsets.all(8),
          child: ListTile(
            leading: imageUrl.isNotEmpty
                ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                : null,
            title: Text(description),
            subtitle: Text('$prix $devise'),
            trailing: Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        );
      },
    ),
  );
}

