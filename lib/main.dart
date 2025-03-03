import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swarm Attack',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Game state
  bool gameStarted = false;
  bool gameOver = false;
  int lives = 3;
  int score = 0;
  int enemiesKilled = 0;

  // Player state
  double playerX = 0.0;
  double playerY = 0.0;
  double playerSpeed = 5.0;
  bool movingUp = false;
  bool movingDown = false;
  bool movingLeft = false;
  bool movingRight = false;

  // Game elements
  List<Bullet> bullets = [];
  List<Enemy> enemies = [];
  List<Explosion> explosions = [];

  // Timers
  late Timer gameTimer;
  late Timer enemySpawnTimer;

  // Controllers for animations
  late AnimationController playerPulseController;

  // Screen dimensions
  double screenWidth = 0;
  double screenHeight = 0;

  final Random random = Random();

  @override
  void initState() {
    super.initState();

    // Set up player pulse animation
    playerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Add keyboard listeners for WASD controls
    RawKeyboard.instance.addListener(_handleKeyEvent);
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyW) {
        movingUp = true;
      } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
        movingDown = true;
      } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
        movingLeft = true;
      } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
        movingRight = true;
      }
    } else if (event is RawKeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyW) {
        movingUp = false;
      } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
        movingDown = false;
      } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
        movingLeft = false;
      } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
        movingRight = false;
      }
    }
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    if (gameStarted) {
      gameTimer.cancel();
      enemySpawnTimer.cancel();
    }
    playerPulseController.dispose();
    super.dispose();
  }

  void startGame() {
    setState(() {
      gameStarted = true;
      gameOver = false;
      lives = 3;
      score = 0;
      enemiesKilled = 0;
      bullets.clear();
      enemies.clear();
      explosions.clear();

      // Position player in center
      playerX = screenWidth / 2;
      playerY = screenHeight / 2;
    });

    // Set up game loop timer (60 FPS)
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      updateGame();
    });

    // Set up enemy spawning timer
    enemySpawnTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      spawnEnemy();
    });
  }

  void updateGame() {
    if (gameOver) return;

    setState(() {
      // Update player position based on movement
      if (movingUp && playerY > 50) playerY -= playerSpeed;
      if (movingDown && playerY < screenHeight - 50) playerY += playerSpeed;
      if (movingLeft && playerX > 50) playerX -= playerSpeed;
      if (movingRight && playerX < screenWidth - 50) playerX += playerSpeed;

      // Update bullets
      for (int i = bullets.length - 1; i >= 0; i--) {
        bullets[i].update();
        if (bullets[i].isOffScreen(screenWidth, screenHeight)) {
          bullets.removeAt(i);
        }
      }

      // Update enemies
      for (int i = enemies.length - 1; i >= 0; i--) {
        Enemy enemy = enemies[i];
        enemy.update(playerX, playerY);

        // Check for collision with player
        if (checkCollision(
            playerX - 25, playerY - 25, 50, 50,
            enemy.x - enemy.size / 2, enemy.y - enemy.size / 2, enemy.size, enemy.size
        )) {
          lives--;
          enemies.removeAt(i);
          addExplosion(enemy.x, enemy.y);

          if (lives <= 0) {
            gameOver = true;
            gameTimer.cancel();
            enemySpawnTimer.cancel();
          }
          continue;
        }

        // Check for collision with bullets
        for (int j = bullets.length - 1; j >= 0; j--) {
          Bullet bullet = bullets[j];
          if (checkCollision(
              bullet.x - 5, bullet.y - 5, 10, 10,
              enemy.x - enemy.size / 2, enemy.y - enemy.size / 2, enemy.size, enemy.size
          )) {
            score += 10;
            enemiesKilled++;

            // Add life after killing 10 enemies
            if (enemiesKilled % 10 == 0) {
              lives++;
            }

            enemies.removeAt(i);
            bullets.removeAt(j);
            addExplosion(enemy.x, enemy.y);
            break;
          }
        }
      }

      // Update explosions
      for (int i = explosions.length - 1; i >= 0; i--) {
        explosions[i].update();
        if (explosions[i].isFinished()) {
          explosions.removeAt(i);
        }
      }
    });
  }

  void spawnEnemy() {
    if (gameOver) return;

    // Determine spawn position (from edges of screen)
    double x, y;
    int side = random.nextInt(4);

    switch (side) {
      case 0: // Top
        x = random.nextDouble() * screenWidth;
        y = -50;
        break;
      case 1: // Right
        x = screenWidth + 50;
        y = random.nextDouble() * screenHeight;
        break;
      case 2: // Bottom
        x = random.nextDouble() * screenWidth;
        y = screenHeight + 50;
        break;
      case 3: // Left
        x = -50;
        y = random.nextDouble() * screenHeight;
        break;
      default:
        x = -50;
        y = -50;
    }

    // Random enemy type
    EnemyType type = EnemyType.values[random.nextInt(EnemyType.values.length)];
    double speed = 1.5 + random.nextDouble();

    setState(() {
      enemies.add(Enemy(x, y, type, speed));
    });
  }

  void shootBullet(Offset position) {
    if (!gameStarted || gameOver) return;

    // Calculate direction from player to tap position
    double dx = position.dx - playerX;
    double dy = position.dy - playerY;
    double distance = sqrt(dx * dx + dy * dy);

    // Normalize direction
    dx = dx / distance;
    dy = dy / distance;

    setState(() {
      bullets.add(Bullet(playerX, playerY, dx, dy, 10.0));
    });
  }

  void addExplosion(double x, double y) {
    setState(() {
      explosions.add(Explosion(x, y));
    });
  }

  bool checkCollision(double x1, double y1, double w1, double h1, double x2, double y2, double w2, double h2) {
    return x1 < x2 + w2 &&
        x1 + w1 > x2 &&
        y1 < y2 + h2 &&
        y1 + h1 > y2;
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: GestureDetector(
        onTapDown: (TapDownDetails details) {
          shootBullet(details.localPosition);
        },
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/space_background.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              // Game elements
              if (gameStarted && !gameOver) ...[
                // Draw bullets
                ...bullets.map((bullet) => Positioned(
                  left: bullet.x - 5,
                  top: bullet.y - 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.cyan,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                )),

                // Draw enemies
                ...enemies.map((enemy) => Positioned(
                  left: enemy.x - enemy.size / 2,
                  top: enemy.y - enemy.size / 2,
                  child: Container(
                    width: enemy.size,
                    height: enemy.size,
                    child: CustomPaint(
                      painter: EnemyPainter(enemy.type),
                    ),
                  ),
                )),

                // Draw explosions
                ...explosions.map((explosion) => Positioned(
                  left: explosion.x - explosion.size / 2,
                  top: explosion.y - explosion.size / 2,
                  child: Container(
                    width: explosion.size,
                    height: explosion.size,
                    child: CustomPaint(
                      painter: ExplosionPainter(explosion.progress),
                    ),
                  ),
                )),

                // Draw player
                Positioned(
                  left: playerX - 25,
                  top: playerY - 25,
                  child: AnimatedBuilder(
                    animation: playerPulseController,
                    builder: (context, child) {
                      return Container(
                        width: 50,
                        height: 50,
                        child: CustomPaint(
                          painter: PlayerPainter(playerPulseController.value),
                        ),
                      );
                    },
                  ),
                ),

                // Game HUD
                Positioned(
                  top: 20,
                  left: 20,
                  child: Text(
                    'Lives: $lives',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  top: 20,
                  right: 20,
                  child: Text(
                    'Score: $score',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Start Screen
              if (!gameStarted)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SWARM ATTACK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              color: Colors.cyan,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: startGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan,
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'START GAME',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Controls: WASD to move, Click to shoot',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),

              // Game Over Screen
              if (gameOver)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'GAME OVER',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.redAccent,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Your Score: $score',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                          ),
                        ),
                        SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: startGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            'PLAY AGAIN',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Game object classes
class Bullet {
  double x, y;
  double dx, dy;
  double speed;

  Bullet(this.x, this.y, this.dx, this.dy, this.speed);

  void update() {
    x += dx * speed;
    y += dy * speed;
  }

  bool isOffScreen(double screenWidth, double screenHeight) {
    return x < -10 || x > screenWidth + 10 || y < -10 || y > screenHeight + 10;
  }
}

enum EnemyType { Spinner, Chaser, Zigzagger }

class Enemy {
  double x, y;
  EnemyType type;
  double speed;
  double size = 40;
  int movementCounter = 0;
  double directionAngle = 0;

  Enemy(this.x, this.y, this.type, this.speed);

  void update(double playerX, double playerY) {
    movementCounter++;

    switch (type) {
      case EnemyType.Spinner:
      // Spiral towards player
        double dx = playerX - x;
        double dy = playerY - y;
        double distance = sqrt(dx * dx + dy * dy);

        if (distance > 0) {
          directionAngle += 0.05;
          x += (dx / distance * speed * 0.8) + sin(directionAngle) * 2;
          y += (dy / distance * speed * 0.8) + cos(directionAngle) * 2;
        }
        break;

      case EnemyType.Chaser:
      // Directly chase player
        double dx = playerX - x;
        double dy = playerY - y;
        double distance = sqrt(dx * dx + dy * dy);

        if (distance > 0) {
          x += dx / distance * speed;
          y += dy / distance * speed;
        }
        break;

      case EnemyType.Zigzagger:
      // Zig-zag towards player
        double dx = playerX - x;
        double dy = playerY - y;
        double distance = sqrt(dx * dx + dy * dy);

        if (distance > 0) {
          double zigzagFactor = sin(movementCounter * 0.1) * 3;

          x += dx / distance * speed + zigzagFactor;
          y += dy / distance * speed + zigzagFactor * 0.5;
        }
        break;
    }
  }
}

class Explosion {
  double x, y;
  double size;
  double progress = 0;
  final double speed = 0.05;

  Explosion(this.x, this.y) : size = 60;

  void update() {
    progress += speed;
  }

  bool isFinished() {
    return progress >= 1.0;
  }
}

// Custom painters
class PlayerPainter extends CustomPainter {
  final double pulseValue;

  PlayerPainter(this.pulseValue);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bodyPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;

    final Paint detailPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Paint glowPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.3 + pulseValue * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 + pulseValue * 2;

    // Draw ship body (triangular shape)
    final Path shipPath = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height * 0.8)
      ..lineTo(size.width / 2, size.height * 0.6)
      ..lineTo(0, size.height * 0.8)
      ..close();

    // Draw engine glow
    final Path enginePath = Path()
      ..moveTo(size.width * 0.3, size.height * 0.8)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.7, size.height * 0.8);

    // Draw cockpit
    final Rect cockpit = Rect.fromLTWH(
      size.width * 0.4,
      size.height * 0.3,
      size.width * 0.2,
      size.height * 0.2,
    );

    // Glow effect based on pulse
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 + pulseValue * 5,
      glowPaint,
    );

    // Draw ship components
    canvas.drawPath(shipPath, bodyPaint);
    canvas.drawPath(shipPath, detailPaint);
    canvas.drawOval(cockpit, Paint()..color = Colors.white.withOpacity(0.8));
    canvas.drawPath(
      enginePath,
      Paint()..color = Colors.orangeAccent.withOpacity(0.5 + pulseValue * 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant PlayerPainter oldDelegate) => true;
}

class EnemyPainter extends CustomPainter {
  final EnemyType type;

  EnemyPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case EnemyType.Spinner:
        _paintSpinner(canvas, size);
        break;
      case EnemyType.Chaser:
        _paintChaser(canvas, size);
        break;
      case EnemyType.Zigzagger:
        _paintZigzagger(canvas, size);
        break;
    }
  }

  void _paintSpinner(Canvas canvas, Size size) {
    final Paint bodyPaint = Paint()
      ..color = Colors.purpleAccent
      ..style = PaintingStyle.fill;

    final Paint detailPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw a circular body with spikes
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2.5,
      bodyPaint,
    );

    // Draw spikes
    for (int i = 0; i < 8; i++) {
      double angle = i * pi / 4;
      double outerRadius = size.width / 2;
      double innerRadius = size.width / 2.5;

      final Path spikePath = Path()
        ..moveTo(
          size.width / 2 + cos(angle) * innerRadius,
          size.height / 2 + sin(angle) * innerRadius,
        )
        ..lineTo(
          size.width / 2 + cos(angle - 0.2) * outerRadius,
          size.height / 2 + sin(angle - 0.2) * outerRadius,
        )
        ..lineTo(
          size.width / 2 + cos(angle + 0.2) * outerRadius,
          size.height / 2 + sin(angle + 0.2) * outerRadius,
        )
        ..close();

      canvas.drawPath(spikePath, bodyPaint);
      canvas.drawPath(spikePath, detailPaint);
    }

    // Draw eye
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 6,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 10,
      Paint()..color = Colors.red,
    );
  }

  void _paintChaser(Canvas canvas, Size size) {
    final Paint bodyPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    final Paint detailPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw main body (octagonal shape)
    final Path bodyPath = Path();
    for (int i = 0; i < 8; i++) {
      double angle = i * pi / 4;
      double radius = size.width / 2.2;

      if (i == 0) {
        bodyPath.moveTo(
          size.width / 2 + cos(angle) * radius,
          size.height / 2 + sin(angle) * radius,
        );
      } else {
        bodyPath.lineTo(
          size.width / 2 + cos(angle) * radius,
          size.height / 2 + sin(angle) * radius,
        );
      }
    }
    bodyPath.close();

    canvas.drawPath(bodyPath, bodyPaint);
    canvas.drawPath(bodyPath, detailPaint);

    // Draw inner details (concentric circles)
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 3,
      Paint()
        ..color = Colors.red.shade800
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 5,
      Paint()
        ..color = Colors.red.shade900
        ..style = PaintingStyle.fill,
    );

    // Draw eyes (multiple small circles)
    for (int i = 0; i < 3; i++) {
      double angle = -pi / 4 + i * pi / 4;
      double radius = size.width / 3.5;

      canvas.drawCircle(
        Offset(
          size.width / 2 + cos(angle) * radius,
          size.height / 2 + sin(angle) * radius,
        ),
        size.width / 12,
        Paint()..color = Colors.yellowAccent,
      );
    }
  }

  void _paintZigzagger(Canvas canvas, Size size) {
    final Paint bodyPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    final Paint detailPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw lightning-shaped body
    final Path bodyPath = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width * 0.7, size.height * 0.2)
      ..lineTo(size.width * 0.3, size.height * 0.4)
      ..lineTo(size.width * 0.7, size.height * 0.6)
      ..lineTo(size.width * 0.3, size.height * 0.8)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.2, size.height * 0.8)
      ..lineTo(size.width * 0.6, size.height * 0.6)
      ..lineTo(size.width * 0.2, size.height * 0.4)
      ..lineTo(size.width * 0.6, size.height * 0.2)
      ..lineTo(size.width * 0.3, 0)
      ..close();

    canvas.drawPath(bodyPath, bodyPaint);
    canvas.drawPath(bodyPath, detailPaint);

    // Draw eye
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.3),
      size.width / 8,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.3),
      size.width / 12,
      Paint()..color = Colors.black,
    );

    // Draw energy bolts
    for (int i = 0; i < 2; i++) {
      double startX = i == 0 ? size.width * 0.2 : size.width * 0.8;

      final Path boltPath = Path()
        ..moveTo(startX, size.height * 0.6)
        ..lineTo(startX + (i == 0 ? 1 : -1) * size.width * 0.1, size.height * 0.7)
        ..lineTo(startX, size.height * 0.8)
        ..lineTo(startX + (i == 0 ? 1 : -1) * size.width * 0.15, size.height * 0.9);

      canvas.drawPath(
        boltPath,
        Paint()
          ..color = Colors.yellowAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant EnemyPainter oldDelegate) => false;
}

class ExplosionPainter extends CustomPainter {
  final double progress;

  ExplosionPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // Outer explosion circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 * progress,
      Paint()
        ..color = Colors.orange.withOpacity(1 - progress)
        ..style = PaintingStyle.fill,
    );

    // Inner explosion circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 3 * progress,
      Paint()
        ..color = Colors.yellow.withOpacity(1 - progress)
        ..style = PaintingStyle.fill,
    );

    // Draw explosion spikes
    for (int i = 0; i < 12; i++) {
      double angle = i * pi / 6;

      double baseRadius = size.width / 2.5 * progress;
      double tipRadius = size.width / 1.5 * progress;

      final Path spikePath = Path()
        ..moveTo(
          size.width / 2 + cos(angle) * baseRadius,
          size.height / 2 + sin(angle) * baseRadius,
        )
        ..lineTo(
          size.width / 2 + cos(angle) * tipRadius,
          size.height / 2 + sin(angle) * tipRadius,
        )
        ..lineTo(
          size.width / 2 + cos(angle + 0.2) * baseRadius,
          size.height / 2 + sin(angle + 0.2) * baseRadius,
        )
        ..close();

      canvas.drawPath(
        spikePath,
        Paint()
          ..color = Colors.red.withOpacity(1 - progress)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ExplosionPainter oldDelegate) => true;
}