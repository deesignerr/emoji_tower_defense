import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(EmojiTowerDefense());

enum EnemyType { normal, heart, extraCoin, bomb, slot }

class Enemy {
  String emoji;
  double position; // 1.0 = right edge, 0.0 = tower
  double speed;
  EnemyType type;
  int lane;
  bool exploded;

  Enemy({
    required this.emoji,
    this.position = 1.0,
    required this.speed,
    required this.type,
    required this.lane,
    this.exploded = false,
  });
}

class EmojiTowerDefense extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emoji Tower Defense',
      home: TowerDefenseGame(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TowerDefenseGame extends StatefulWidget {
  @override
  _TowerDefenseGameState createState() => _TowerDefenseGameState();
}

class _TowerDefenseGameState extends State<TowerDefenseGame> {
  final Random random = Random();
  List<Enemy> enemies = [];
  int health = 5;
  int score = 0;
  int topScore = 0;
  Timer? gameTimer;
  double baseSpeed = 0.002;
  bool isGameOver = false;

  final int maxEnemiesOnScreen = 10;
  final int totalLanes = 10;

  Set<int> usedLanes = {};
  List<String> enemyEmojis = ['👾', '👹', '🤡', '👻', '🧟'];

  // Slot machine state
  bool isSlotMachineActive = false;
  List<String> slotResult = ["❓", "❓", "❓"];
  int slotReward = 0;

  // Neon colors
  final Color neonPink = Color(0xFFFF2D95);
  final Color electricBlue = Color(0xFF3B82F6);
  final Color vibrantPurple = Color(0xFF8B5CF6);
  final Color brightCyan = Color(0xFF06B6D4);
  final Color sunnyYellow = Color(0xFFFBBF24);
  final Color darkBackground = Color(0xFF111827);

  @override
  void initState() {
    super.initState();
    startGame();
  }

  void startGame() {
    enemies.clear();
    health = 5;
    score = 0;
    isGameOver = false;
    baseSpeed = 0.002;
    usedLanes.clear();
    isSlotMachineActive = false;

    gameTimer?.cancel();
    gameTimer = Timer.periodic(Duration(milliseconds: 30), (_) {
      if (isGameOver || isSlotMachineActive) return;
      setState(() {
        for (var enemy in enemies) {
          if (!enemy.exploded) enemy.position -= enemy.speed;
        }

        enemies.removeWhere((enemy) {
          if (enemy.position <= 0) {
            usedLanes.remove(enemy.lane);
            if (enemy.type == EnemyType.normal) {
              health--;
              if (health <= 0) gameOver();
            }
            return true;
          }
          return false;
        });

        if (enemies.length < maxEnemiesOnScreen) {
          if (random.nextDouble() < 0.04) spawnEnemy();
        }

        // Speed growth
        double targetSpeed;
        if (score <= 900) {
          targetSpeed = 0.002 * pow(1.05, score ~/ 10);
        } else {
          double over900 = score - 900;
          targetSpeed = 0.002 * pow(1.05, 90) * pow(1.2, over900 / 10);
        }
        if (baseSpeed < targetSpeed) baseSpeed += 0.00002;
      });
    });
  }

  void spawnEnemy() {
    List<int> availableLanes = List.generate(totalLanes, (i) => i)
        .where((lane) => !usedLanes.contains(lane))
        .toList();
    if (availableLanes.isEmpty) return;

    int lane = availableLanes[random.nextInt(availableLanes.length)];
    usedLanes.add(lane);

    double roll = random.nextDouble();
    EnemyType type;
    String emoji;

    if (roll < 0.01) {
      type = EnemyType.heart;
      emoji = '❤️';
    } else if (roll < 0.03) {
      type = EnemyType.extraCoin;
      emoji = '🪙';
    } else if (roll < 0.05) {
      type = EnemyType.bomb;
      emoji = '💣';
    } else if (roll < 0.08) {
      type = EnemyType.slot;
      emoji = '🎰';
    } else {
      type = EnemyType.normal;
      emoji = enemyEmojis[random.nextInt(enemyEmojis.length)];
    }

    enemies.add(Enemy(
      emoji: emoji,
      position: 1.0,
      speed: baseSpeed + random.nextDouble() * 0.003,
      type: type,
      lane: lane,
    ));
  }

  void shootEnemy(Enemy enemy) {
    if (isGameOver) return;

    setState(() {
      usedLanes.remove(enemy.lane);

      if (enemy.type == EnemyType.heart) {
        health++;
      } else if (enemy.type == EnemyType.extraCoin) {
        score += 2;
      } else if (enemy.type == EnemyType.bomb) {
        triggerBombExplosion();
      } else if (enemy.type == EnemyType.normal) {
        score++;
      } else if (enemy.type == EnemyType.slot) {
        triggerSlotMachine();
      }

      enemies.remove(enemy);
    });
  }

  void triggerBombExplosion() {
    int killed = 0;
    for (var e in enemies) {
      if (!e.exploded) {
        e.exploded = true;
        e.emoji = '💥';
        if (e.type == EnemyType.normal) killed++;
        else if (e.type == EnemyType.extraCoin) killed += 2;
        else if (e.type == EnemyType.heart) health++;
      }
    }

    setState(() => score += killed);

    Timer(Duration(milliseconds: 700), () {
      setState(() {
        enemies.clear();
        usedLanes.clear();
      });
    });
  }

  // ------------------- Slot Machine Logic -------------------
  void triggerSlotMachine() {
    setState(() {
      isSlotMachineActive = true;
      slotResult = ["❓", "❓", "❓"];
      slotReward = 0;
    });

    List<String> finalResult = decideSlotOutcome();

    // Extra delay if first two are coins or bags
    bool extraDelay = (finalResult[0] == "🪙" && finalResult[1] == "🪙") ||
        (finalResult[0] == "💰" && finalResult[1] == "💰");

    spinReel(0, finalResult[0], 0, then: () {
      spinReel(1, finalResult[1], 400, then: () {
        spinReel(2, finalResult[2], extraDelay ? 1000 : 700, then: () {
          finishSlotMachine(finalResult);
        });
      });
    });
  }

  void spinReel(int index, String finalEmoji, int extraDurationMs, {VoidCallback? then}) {
    int tick = 0;
    Timer.periodic(Duration(milliseconds: 80), (timer) {
      tick++;
      setState(() {
        slotResult[index] = randomChoice(["🪙", "❌", "💰"]);
      });

      if (tick >= 12 + extraDurationMs ~/ 80) {
        setState(() => slotResult[index] = finalEmoji);
        timer.cancel();
        if (then != null) then();
      }
    });
  }

  String randomChoice(List<String> options) => options[random.nextInt(options.length)];

List<String> decideSlotOutcome() {
  double roll = random.nextDouble();
  
  if (roll < 0.01) {
    // 1% → jackpot 💰💰💰
    return ["💰", "💰", "💰"];
  } else if (roll < 0.51) {
    // 49% → regular win 🪙🪙🪙, random 5-200, >100 rare
    return ["🪙", "🪙", "🪙"];
  } else if (roll < 0.71) {
    // 20% → exactly 2 coins
    List<String> result = ["🪙", "🪙", "❌"];
    result.shuffle();
    return result;
  } else if (roll < 0.91) {
    // 20% → exactly 2 money bags 💰
    List<String> result = ["💰", "💰", "❌"];
    result.shuffle();
    return result;
  } else {
    // 8% → 🪙 or 💰 and random last one
    String first = randomChoice(["🪙", "💰"]);
    String second = randomChoice(["🪙", "💰", "❌"]);
    String third = randomChoice(["🪙", "💰", "❌"]);
    return [first, second, third];
  }
  }

  void finishSlotMachine(List<String> result) {
    int reward = 0;
    if (result.every((s) => s == "💰")) reward = 500;
    else if (result.every((s) => s == "🪙")) {
      reward = random.nextDouble() < 0.1 ? 101 + random.nextInt(99) : 5 + random.nextInt(95);
    }

    setState(() {
      score += reward;
      slotReward = reward;
    });

    Timer(Duration(seconds: 3), () {
      setState(() => isSlotMachineActive = false);
    });
  }

  // ------------------- Game Over -------------------
  void gameOver() {
    gameTimer?.cancel();
    isGameOver = true;
    if (score > topScore) topScore = score;
  }

  void restart() => startGame();

  // ------------------- UI Helpers -------------------
  void showHowToPlay() {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text("How to Play"),
              content: Text(
                  "Tap the enemies to destroy them.\n ❤️ increase health.\n 🪙 Gives you extra coins.\n 💣 destroy everything on the screen.\n 🎰 Can give bonus coins.\n If you reach 1000 coins you win a \$100 gift card!"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text("Close"))
              ],
            ));
  }

  void openWinners() async {
    Uri url = Uri.parse("https://towerdefence.dreamhosters.com/gift-card/");
    if (!await launchUrl(url)) throw "Could not launch $url";
  }

  Color getRandomNeonColor() {
    List<Color> neonColors = [neonPink, electricBlue, vibrantPurple, brightCyan, sunnyYellow];
    return neonColors[random.nextInt(neonColors.length)];
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    double towerSize = screenHeight * 0.10; 
    double enemySize = screenWidth * 0.08; 
    double slotFontSize = screenWidth * 0.12; 

    return Scaffold(
      backgroundColor: darkBackground,
      body: Stack(
        children: [
          // Tower
          Positioned(
            left: 20,
            top: screenHeight * 0.5 - towerSize / 2,
            child: Text(
              '🏰',
              style: TextStyle(fontSize: towerSize, shadows: [Shadow(color: electricBlue.withOpacity(0.7), blurRadius: 15)]),
            ),
          ),

// Top UI row 1: Goal + Winners
Positioned(
  top: 4,
  left: 0,
  right: 0,
  child: Padding(
    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: "Reach 1000 coins, win a ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: brightCyan, // original color
                    shadows: [
                      Shadow(color: brightCyan.withOpacity(0.8), blurRadius: 8),
                      Shadow(color: Colors.white.withOpacity(0.3), blurRadius: 4),
                    ],
                  ),
                ),
                TextSpan(
                  text: "\$100 gift",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: sunnyYellow, // only this part in sunnyYellow
                    shadows: [
                      Shadow(color: sunnyYellow.withOpacity(0.8), blurRadius: 8),
                      Shadow(color: Colors.white.withOpacity(0.3), blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(width: 6),
        TextButton(
          onPressed: openWinners,
          style: TextButton.styleFrom(
            backgroundColor: Color(0xFF0A2540), // dark button background
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: Text(
            "Read more",
            style: TextStyle(
              color: brightCyan,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  ),
),


// Top UI row 2: Health + info | Score + High Score
Positioned(
  top: 60, // keeps the row positioned from the top
  left: 0,
  right: 0,
  child: Padding(
    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start, // aligns health to top
      children: [
        Row(
          children: [
            Icon(Icons.favorite, color: neonPink, size: 28),
            SizedBox(width: 6),
            Text(
              '$health',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: neonPink,
                shadows: [Shadow(color: neonPink.withOpacity(0.7), blurRadius: 10)],
              ),
            ),
            SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.info, color: electricBlue),
              onPressed: showHowToPlay,
              tooltip: "How to Play",
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '🪙 $score',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: sunnyYellow,
                    shadows: [Shadow(color: sunnyYellow.withOpacity(0.8), blurRadius: 12)]),
              ),
            ),
            SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '🔥 High Score: $topScore',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: vibrantPurple,
                    shadows: [Shadow(color: vibrantPurple.withOpacity(0.8), blurRadius: 10)]),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
),


          // Enemies
          ...enemies.map((enemy) {
            double x = screenWidth * enemy.position;
            double laneHeight = (screenHeight - 200) / totalLanes;
            double y = 100 + enemy.lane * laneHeight;
            Color neonColor = (enemy.type == EnemyType.heart) ? neonPink : getRandomNeonColor();
            double size = (enemy.type == EnemyType.heart) ? enemySize * 1.2 : enemySize;
            if (enemy.exploded) {
              neonColor = Colors.deepOrangeAccent;
              size *= 1.2;
            }
            return Positioned(
              left: x,
              top: y,
              child: GestureDetector(
                onTap: () => shootEnemy(enemy),
                child: Text(enemy.emoji,
                    style: TextStyle(fontSize: size, color: neonColor, shadows: [Shadow(color: neonColor.withOpacity(0.9), blurRadius: 15)])),
              ),
            );
          }).toList(),

          // Slot Machine
          if (isSlotMachineActive)
            Center(
              child: Container(
                width: screenWidth * 0.8,
                padding: EdgeInsets.all(screenWidth * 0.05),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: neonPink.withOpacity(0.7), blurRadius: 30, spreadRadius: 6)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🎰 Win up to 500 coins',
                        style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                            color: sunnyYellow,
                            shadows: [Shadow(color: sunnyYellow.withOpacity(0.9), blurRadius: 15)])),
                    SizedBox(height: 20),
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: slotResult
      .map((e) {
        Color glowColor;
        if (e == "🪙") glowColor = sunnyYellow;
        else if (e == "💰") glowColor = electricBlue;
        else glowColor = vibrantPurple; // fallback for ❌ or others

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            e,
            style: TextStyle(
              fontSize: slotFontSize,
              shadows: [
                Shadow(color: glowColor.withOpacity(0.9), blurRadius: 15),
                Shadow(color: glowColor.withOpacity(0.7), blurRadius: 30),
              ],
            ),
          ),
        );
      }).toList(),
                    ),
                    if (slotReward > 0) ...[
                      SizedBox(height: 20),
                      Text('+ $slotReward coins!',
                          style: TextStyle(
                              fontSize: screenWidth * 0.06,
                              fontWeight: FontWeight.bold,
                              color: electricBlue,
                              shadows: [Shadow(color: electricBlue.withOpacity(0.8), blurRadius: 12)])),
                    ],
                  ],
                ),
              ),
            ),

          // Game Over
          if (isGameOver)
            Center(
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: neonPink.withOpacity(0.6), blurRadius: 30, spreadRadius: 5)]),
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('💥 Game Over!',
                        style: TextStyle(
                            fontSize: screenWidth * 0.07,
                            fontWeight: FontWeight.bold,
                            color: neonPink,
                            shadows: [Shadow(color: neonPink.withOpacity(0.9), blurRadius: 12)])),
                    SizedBox(height: 10),
                    Text('Coins: $score', style: TextStyle(fontSize: screenWidth * 0.06, color: sunnyYellow, fontWeight: FontWeight.bold)),
                    Text('High Score: $topScore',
                        style: TextStyle(fontSize: screenWidth * 0.05, color: vibrantPurple, fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: neonPink,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      onPressed: restart,
                      child: Text('Play Again', style: TextStyle(fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
