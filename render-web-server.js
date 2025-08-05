const express = require('express'); // on utilise Express, un outil pour faire un serveur web facile
const app = express(); // on crée le serveur
const PORT = process.env.PORT || 10000; // on choisit le port (Render donne un port automatiquement)

app.use(express.static('build/web')); // on dit au serveur : "tout ce qui est dans build/web, c’est du contenu statique à montrer"

app.get('*', (req, res) => { // pour toutes les adresses, renvoie la page index.html
  res.sendFile(__dirname + '/build/web/index.html');
});

app.listen(PORT, () => { // on démarre le serveur sur le port choisi
  console.log(`Server running on port ${PORT}`);
});
