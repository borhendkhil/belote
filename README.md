# Belote Contrée tunisienne — version fictive

Jeu de belote contrée multijoueur en ligne, avec moteur de règles Dart
autoritaire, serveur WebSocket et application mobile Flutter bilingue FR/EN.

## Contenu du dépôt

```
bellote/
├── packages/bellote_engine/   Moteur de règles pur Dart, sans UI
│   ├── lib/                   API publique et vues filtrées par siège
│   └── test/                  Tests des règles (enchères, jeu, score, capot)
├── server/                    Serveur WebSocket autoritaire
│   ├── bin/server.dart        Point d'entrée (HTTP + /ws + /health)
│   └── lib/                   Salles, sièges, bots, minuteries, diffusion
└── apps/bellote_app/          Application Flutter (Android, iOS, web)
    ├── lib/                   Écrans, widgets, client WebSocket, l10n
    └── test/                  Tests de localisation et de fumée
```

Le moteur est la seule source de vérité : le serveur refuse toute action
illégale et l'application n'affiche que les actions autorisées par la vue
`PlayerView` reçue.

## Règles implémentées

- 32 cartes, 4 joueurs, 2 équipes (sièges pairs / impairs).
- Distribution de 8 cartes ; redistribution si une main contient 7 ou 8 cartes
  de la même couleur, si le total d'une main dépasse 12 points (valeurs hors
  atout), ou après quatre passes.
- Enchères de 90 à 180 par pas de 10, ou capot. Le capot est au-dessus de tout
  et ne peut pas être contré. Trois passes après la dernière annonce ferment
  les enchères.
- Contre et surcontre (hors tour), belote-rebelote déclarée au choix du joueur
  une seule fois en jouant le roi ou la dame d'atout (20 points), rebelote
  validée automatiquement, dix de der (10 points).
- Le joueur à droite du donneur parle et entame ; jeu dans le sens
  anti-horaire (`(siège + 1) % 4`).
- Obligation de fournir la couleur, de monter à l'atout, de couper ou
  surcouper selon le cas, et de jouer atout lorsqu'un joueur est bloqué.

> On the final trick (dernier pli), play is forced.
>
> Even if only one card playable in hand, do not play it automatically or when the turn timer expires, the card must still be played automatically/by rule.

Traduction : le client ne joue jamais seul, même avec une seule carte légale,
et le serveur n'abrège pas le délai. À l'échéance des 45 secondes, le serveur
joue la carte légale par règle avec `declareBelote: false` : la belote reste un
choix du joueur et n'est jamais annoncée automatiquement.
- Contrat réussi si les points arrondis de l'attaque atteignent le montant.
  Contrat chuté : 160 à la défense ; contré : 320 ; surcontré : 640 ;
  capot demandé : 500 ; capot non demandé : 250.
- Arrêt anticipé dès que le contrat devient mathématiquement impossible, ou
  dès que la défense remporte un pli sur un capot.
- Sets : meilleur des 3 (objectif 2000), meilleur des 5 (objectif 2000), ou set
  unique (objectif 3000). Égalité au seuil : nouvelle donne dans le set.
- Après le début de la partie, un joueur qui quitte volontairement ne peut
  plus revenir : son siège reste joué par un bot jusqu'à la fin.
- Avant le lancement, l'hôte (admin) peut échanger deux sièges pour composer
  les équipes : les sièges pairs jouent ensemble, comme les sièges impairs.

## Prérequis

- Dart SDK 3.6 ou plus récent (`dart --version`).
- Flutter 3.24 ou plus récent pour l'application (`flutter --version`).
- Pour tester sur téléphone : le serveur et le téléphone sur le même réseau
  local.

## Lancer le serveur

```bash
cd server
dart pub get
dart run bin/server.dart -p 8080
```

Le serveur affiche son adresse LAN, par exemple :

```
Belote server listening on http://192.168.1.10:8080
WebSocket: ws://192.168.1.10:8080/ws
```

- Santé : `GET /health`
- WebSocket : `ws://<hôte>:8080/ws`
- Test réseau de bout en bout (hôte + 3 bots, une donne complète) :
  `dart run tool/network_smoke.dart ws://127.0.0.1:8080/ws`

## Déployer le serveur sur Render

Le dépôt contient un `Dockerfile` (compilation Dart en binaire AOT) et un
`render.yaml` (Blueprint) : Render n'a pas de runtime Dart natif, donc le
service est déployé comme un conteneur Docker.

1. Pousser le dépôt sur GitHub / GitLab (le serveur dépend de
   `packages/bellote_engine` : il faut donc tout le monorepo, pas seulement
   `server/`).
2. Sur https://dashboard.render.com : **New → Blueprint**, sélectionner le
   dépôt. Render détecte `render.yaml` et crée le service `bellote-server`.
   - Alternative : **New → Web Service**, connecter le dépôt, Runtime `Docker`,
     build context = racine du dépôt, Health Check Path = `/health`.
3. Le port d'écoute est fourni par Render dans `PORT` (10000 par défaut) ;
   le serveur lit cette variable et écoute sur `0.0.0.0`.
4. Une fois le déploiement terminé, tester :

```bash
curl https://bellote-server.onrender.com/health
dart run server/tool/network_smoke.dart wss://bellote-server.onrender.com/ws
```

5. Reconstruire l'application avec l'URL publique **wss** (obligatoire : Render
   redirige `ws` vers TLS et les clients WebSocket échouent) :

```bash
cd apps/bellote_app
flutter build apk --release \
  --dart-define=BELLOTE_SERVER=wss://bellote-server.onrender.com/ws
```

L'adresse reste modifiable dans l'écran Réglages de l'application.

Limites à connaître :

- Les salles sont en mémoire : un redémarrage du serveur efface les parties en
  cours (les clients peuvent créer une nouvelle salle).
- Une seule instance : ne pas activer le scaling horizontal, sinon les joueurs
  d'une même salle peuvent atterrir sur des instances différentes.
- Le plan Free met le service en veille après 15 minutes sans trafic entrant
  (le réveil prend environ une minute). L'application envoie un `ping` toutes
  les 25 secondes : une partie avec au moins un client connecté reste active.
  Un plan payant reste recommandé pour éviter les redémarrages liés aux
  déploiements et à la maintenance.
- Le client conserve la session (code + token) et se reconnecte automatiquement
  après une coupure, tant que le joueur n'a pas quitté volontairement la partie.

## Lancer les tests

```bash
# Moteur
cd packages/bellote_engine
dart pub get
dart analyze
dart test

# Serveur
cd server
dart pub get
dart analyze

# Application
cd apps/bellote_app
flutter pub get
flutter analyze
flutter test
```

## Lancer l'application

L'URL du serveur par défaut est `ws://localhost:8080/ws`. Elle peut être
remplacée au lancement avec `--dart-define=BELLOTE_SERVER=...`, ou dans
l'écran Réglages de l'application.

### Web (test rapide sur ordinateur)

```bash
cd apps/bellote_app
flutter run -d chrome --dart-define=BELLOTE_SERVER=ws://192.168.1.10:8080/ws
```

### Android / iOS

```bash
cd apps/bellote_app
flutter run --dart-define=BELLOTE_SERVER=ws://192.168.1.10:8080/ws
```

Pensez à autoriser le trafic HTTP non chiffré en développement si nécessaire
(le serveur local utilise `ws://`, pas `wss://`). Le manifeste Android active
déjà `android:usesCleartextTraffic="true"`.

### Build Android (APK)

Prérequis : JDK 17 et le SDK Android (plateforme 36, build-tools 36.0.0).
`flutter doctor` doit afficher la coche « Android toolchain ».

```bash
cd apps/bellote_app
flutter build apk --release \
  --dart-define=BELLOTE_SERVER=ws://192.168.1.10:8080/ws
```

L'APK universel (toutes architectures) est généré dans
`build/app/outputs/flutter-apk/app-release.apk`.

Pour un APK plus léger par architecture :

```bash
flutter build apk --release --split-per-abi \
  --dart-define=BELLOTE_SERVER=ws://192.168.1.10:8080/ws
```

Installation sur un téléphone branché en USB :

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Sans câble, copiez l'APK sur le téléphone et autorisez l'installation
depuis une source inconnue.

Le build de release utilise pour l'instant la clé de debug (installable, mais
pas publiable sur le Play Store). Pour signer avec votre propre clé :

```bash
keytool -genkey -v -keystore ~/bellote-release.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias bellote
```

puis remplacez `signingConfig = signingConfigs.getByName("debug")` dans
`android/app/build.gradle.kts` par une configuration `release` alimentée par
un fichier `android/key.properties` (non versionné).

### Build web

```bash
cd apps/bellote_app
flutter build web --dart-define=BELLOTE_SERVER=ws://192.168.1.10:8080/ws
```

## Déroulement d'une partie

1. Un joueur crée une salle : un code à 5 caractères est généré.
2. Les autres joueurs rejoignent avec ce code (4 sièges au total).
3. L'hôte peut ajouter des bots pour compléter la table, puis lance la partie.
4. Les joueurs enchérissent, contrrent ou surcontrent selon les actions
   proposées. L'interface ne montre que les montants et cartes légaux.
5. Une donne terminée affiche le détail des points. La donne suivante démarre
   automatiquement après 6 secondes ; l'hôte peut aussi la lancer tout de suite.
6. Un joueur déconnecté est temporairement contrôlé par un bot et peut revenir
   avec la même session.

## Protocole WebSocket

Messages client : `create`, `join`, `reconnect`, `pass`, `bid`, `capot`,
`counter`, `surcounter`, `play`, `nextDeal`, `addBot`, `removeBot`, `start`,
`chat`, `leave`, `ping`.

Messages serveur : `hello`, `welcome`, `room`, `state` (avec `view` filtrée par
siège), `chat`, `notice`, `error`, `pong`, `left`.

Chaque client ne reçoit que sa propre main et le nombre de cartes adverses.

## Limites connues

- Les salles sont en mémoire : redémarrer le serveur efface les parties.
- Pas d'authentification de compte ; la reconnexion repose sur un jeton de
  session aléatoire.
- Pas de TLS intégré : utilisez un reverse proxy pour `wss://` en production.
- Les bots utilisent une heuristique simple, pas une recherche exhaustive.
- L'application cible le réseau local ; l'hébergement public reste à configurer.
