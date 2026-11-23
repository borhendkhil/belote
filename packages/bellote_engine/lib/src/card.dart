import 'package:meta/meta.dart';

/// Les quatre couleurs, dans l'ordre traditionnel de la belote
/// (pique > cœur > carreau > trèfle).
enum Suit {
  spades('S', '♠'),
  hearts('H', '♥'),
  diamonds('D', '♦'),
  clubs('C', '♣');

  const Suit(this.code, this.symbol);

  final String code;
  final String symbol;

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;

  static Suit fromCode(String code) {
    for (final suit in Suit.values) {
      if (suit.code == code) return suit;
    }
    throw ArgumentError.value(code, 'code', 'Couleur inconnue');
  }

  static Suit fromName(String name) {
    final normalized = name.toLowerCase();
    for (final suit in Suit.values) {
      if (suit.name == normalized) return suit;
    }
    return fromCode(name.toUpperCase());
  }
}

/// Les huit rangs, du plus faible au plus fort au sens de l'ordre naturel.
enum Rank {
  seven('7', 7),
  eight('8', 8),
  nine('9', 9),
  ten('10', 10),
  jack('J', 11),
  queen('Q', 12),
  king('K', 13),
  ace('A', 14);

  const Rank(this.code, this.faceValue);

  final String code;
  final int faceValue;

  static Rank fromCode(String code) {
    for (final rank in Rank.values) {
      if (rank.code == code) return rank;
    }
    throw ArgumentError.value(code, 'code', 'Rang inconnu');
  }
}

/// Points des cartes à l'atout.
const Map<Rank, int> trumpPoints = {
  Rank.jack: 20,
  Rank.nine: 14,
  Rank.ace: 11,
  Rank.ten: 10,
  Rank.king: 4,
  Rank.queen: 3,
  Rank.eight: 0,
  Rank.seven: 0,
};

/// Points des cartes hors atout.
const Map<Rank, int> plainPoints = {
  Rank.ace: 11,
  Rank.ten: 10,
  Rank.king: 4,
  Rank.queen: 3,
  Rank.jack: 2,
  Rank.nine: 0,
  Rank.eight: 0,
  Rank.seven: 0,
};

/// Force relative des cartes à l'atout (7 = plus fort).
const Map<Rank, int> trumpStrength = {
  Rank.jack: 7,
  Rank.nine: 6,
  Rank.ace: 5,
  Rank.ten: 4,
  Rank.king: 3,
  Rank.queen: 2,
  Rank.eight: 1,
  Rank.seven: 0,
};

/// Force relative des cartes hors atout (7 = plus fort).
const Map<Rank, int> plainStrength = {
  Rank.ace: 7,
  Rank.ten: 6,
  Rank.king: 5,
  Rank.queen: 4,
  Rank.jack: 3,
  Rank.nine: 2,
  Rank.eight: 1,
  Rank.seven: 0,
};

@immutable
class Card implements Comparable<Card> {
  const Card(this.rank, this.suit);

  final Rank rank;
  final Suit suit;

  /// Identifiant compact, par exemple `AS`, `10H`, `7C`.
  String get id => '${rank.code}${suit.code}';

  bool get isRed => suit.isRed;

  int points(Suit trump) =>
      suit == trump ? trumpPoints[rank]! : plainPoints[rank]!;

  int strength(Suit trump) =>
      suit == trump ? trumpStrength[rank]! : plainStrength[rank]!;

  static Card parse(String id) {
    final trimmed = id.trim().toUpperCase();
    if (trimmed.length < 2) {
      throw FormatException('Carte invalide: $id');
    }
    final suit = Suit.fromCode(trimmed.substring(trimmed.length - 1));
    final rank = Rank.fromCode(trimmed.substring(0, trimmed.length - 1));
    return Card(rank, suit);
  }

  Map<String, dynamic> toJson() => {'id': id};

  static Card fromJson(Object? json) {
    if (json is String) return parse(json);
    if (json is Map<String, dynamic> && json['id'] is String) {
      return parse(json['id'] as String);
    }
    throw FormatException('Carte JSON invalide: $json');
  }

  @override
  int compareTo(Card other) {
    final suitCompare = suit.index.compareTo(other.suit.index);
    if (suitCompare != 0) return suitCompare;
    return rank.index.compareTo(other.rank.index);
  }

  @override
  bool operator ==(Object other) =>
      other is Card && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => id;
}

/// Jeu complet de 32 cartes, dans un ordre déterministe.
List<Card> fullDeck() => [
      for (final suit in Suit.values)
        for (final rank in Rank.values) Card(rank, suit),
    ];

/// Somme des points des 32 cartes pour une couleur d'atout donnée.
int totalDeckPoints(Suit trump) =>
    fullDeck().fold(0, (sum, card) => sum + card.points(trump));

/// Trie une main pour l'affichage : couleurs groupées, atout en dernier,
/// rangs décroissants à l'intérieur de chaque couleur.
List<Card> sortHand(List<Card> hand, {Suit? trump}) {
  final sorted = [...hand];
  sorted.sort((a, b) {
    if (trump != null && (a.suit == trump) != (b.suit == trump)) {
      return a.suit == trump ? 1 : -1;
    }
    final suitCompare = a.suit.index.compareTo(b.suit.index);
    if (suitCompare != 0) return suitCompare;
    return b.rank.faceValue.compareTo(a.rank.faceValue);
  });
  return sorted;
}
