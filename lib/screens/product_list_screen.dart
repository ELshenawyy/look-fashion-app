import 'package:flutter/material.dart';
import 'package:my_fashion_app/models/product.dart';
import 'package:my_fashion_app/pages/product_detail_screen.dart';
import 'package:my_fashion_app/services/product_service.dart';
import 'package:my_fashion_app/screens/products.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({Key? key}) : super(key: key);

  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final List<String> allimages = [
    'assets/mobile.png',
    'assets/aa.png',
    'assets/aaa.png',
    'assets/bb.png',
    'assets/bbb.png',
    'assets/cc.png',
    'assets/ccc.png',
    'assets/dd.png',
    'assets/ddd.png',
    'assets/ee.png',
    'assets/eee.png',
  ];
  final ProductService productService = ProductService();
  final TextEditingController _searchController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isSearchFocused = false;
  bool _isListening = false;
  late Timer _timer;
  int currentIndex = 0;

  @override
  void dispose() {
    _speech.stop();
    _searchController.dispose();
    _timer.cancel(); // cancel the timer when the widget is disposed
    super.dispose();
  }

  Future<void> _startListening() async {
    bool isAvailable = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          _isListening = status == 'listening';
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _speechAvailable = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'عذراً، حدث خطأ في التعرف على الصوت. تحقق من صلاحيات الميكروفون.'),
          ),
        );
      },
    );

    if (mounted) {
      setState(() => _speechAvailable = isAvailable);
    }

    if (!isAvailable) {
      if (mounted) {
        setState(() {
          _speechAvailable = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'التعرف الصوتي غير مفعل. يرجى السماح بالوصول إلى الميكروفون من إعدادات الجهاز.')),
        );
        await _showSpeechPermissionDialog();
      }
      return;
    }

    _speech.listen(onResult: (result) {
      if (!mounted) return;
      setState(() {
        _searchController.text = result.recognizedWords;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );
      });
    });
  }

  void _stopListening() {
    _speech.stop();
    if (!mounted) return;
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _showSpeechPermissionDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ترخيص الميكروفون مطلوب'),
        content: Text(
            'التعرف الصوتي غير مفعل. الرجاء السماح بالوصول إلى الميكروفون من إعدادات التطبيق ثم إعادة المحاولة.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startListening();
            },
            child: Text('إعادة المحاولة'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // start the timer when the widget is initialized
    _timer = Timer.periodic(Duration(seconds: 4), (timer) {
      setState(() {
        currentIndex = (currentIndex + 1) % allimages.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isSearchFocused) {
          setState(() {
            _isSearchFocused = false;
          });
          _searchController.clear();
          FocusScope.of(context).unfocus();
          _stopListening();
        }
      },
      child: Scaffold(
        backgroundColor: Color.fromARGB(255, 0, 0, 0),
        appBar: AppBar(
          backgroundColor: Color.fromARGB(255, 0, 0, 0),
          elevation: 0,
          toolbarHeight: 50,
          automaticallyImplyLeading: false,
          title: Text(
            'My Fashion App',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          actions: [
            Container(
              margin: EdgeInsets.only(right: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                    color: Color.fromARGB(255, 141, 71, 71), width: 2),
              ),
              child: IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.asset('assets/icon.png'),
                  ),
                ),
                onPressed: () {},
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                'Discover the best app',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Text(
                  'To buy and choose clothes',
                  style: TextStyle(
                    color: Color.fromARGB(255, 255, 230, 0),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                width: _isSearchFocused ? 350 : 350,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 87, 7, 7),
                  border: Border.all(
                    color: Color.fromARGB(255, 255, 255, 255),
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for products or tap the mic',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                      ),
                      style: TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                      ),
                      cursorHeight: 20,
                      cursorWidth: 2,
                      cursorColor: Color.fromARGB(255, 255, 255, 255),
                      textInputAction: TextInputAction.search,
                      maxLines: 1,
                      textAlignVertical: TextAlignVertical.center,
                      autofocus: true,
                      onChanged: (value) {
                        setState(
                            () {}); // Trigger rebuild to update the filtered list
                      },
                      onSubmitted: (value) {
                        // Perform search
                      },
                    )),
                    SizedBox(width: 10),
                    IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening
                            ? Colors.yellow
                            : Color.fromARGB(255, 255, 255, 255),
                      ),
                      onPressed: () async {
                        if (_isListening) {
                          _stopListening();
                        } else {
                          await _startListening();
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.search,
                        color: Color.fromARGB(255, 255, 255, 255),
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearchFocused = !_isSearchFocused;
                          if (!_isSearchFocused) {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                            _stopListening();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              if (!_speechAvailable && !_isListening)
                Padding(
                  padding:
                      EdgeInsets.only(top: 6, bottom: 6, left: 20, right: 20),
                  child: Text(
                    'التعرف الصوتي غير مفعل; يرجى السماح بالوصول إلى الميكروفون من إعدادات الجهاز أو السحب للأعلى لإعادة المحاولة.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              Container(
                margin: EdgeInsets.only(top: 20),
                height: 240,
                width: 360,
                child: PageView.builder(
                  itemCount: allimages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              allimages[
                                  (index + currentIndex) % allimages.length],
                              fit: BoxFit.cover,
                              height: 240,
                              width: 360,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6)
                                ],
                              ),
                            ),
                            padding: EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => Productss()),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Color.fromARGB(255, 0, 0, 0)),
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.grey,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6.0, vertical: 2.0),
                                    child: Text(
                                      'Learn More',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 87, 7, 7),
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'times new roman',
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 8.0,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                    ),
                                    SizedBox(width: 4.0),
                                    Icon(
                                      Icons.circle,
                                      size: 8.0,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                    ),
                                    SizedBox(width: 4.0),
                                    Icon(
                                      Icons.circle,
                                      size: 8.0,
                                      color: Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 87, 7, 7),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New Arrival Collection',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 255, 251, 0),
                              fontFamily: 'times new roman',
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 0, 0, 0),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => Productss()));
                              },
                              child: Text(
                                'See all',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 255, 255, 255),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 10,
                        children: [
                          FilterButton(
                            label: 'Popular',
                            isSelected: false,
                            onPressed: () {},
                          ),
                          FilterButton(
                            label: 'Trending',
                            isSelected: false,
                          ),
                          FilterButton(
                            label: 'New',
                            isSelected: false,
                          ),
                          FilterButton(
                            label: 'Summer',
                            isSelected: false,
                          ),
                          FilterButton(
                            label: 'OverSize',
                            isSelected: false,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 20),
                      height: 220,
                      width: 380,
                      child: StreamBuilder<List<Product>>(
                        stream: productService.getProductsStream(),
                        builder: (BuildContext context,
                            AsyncSnapshot<List<Product>> snapshot) {
                          if (snapshot.hasData) {
                            List<Product> products = snapshot.data!;
                            if (_searchController.text.isNotEmpty) {
                              products = products
                                  .where((product) => product.title
                                      .toLowerCase()
                                      .contains(
                                          _searchController.text.toLowerCase()))
                                  .toList();
                            }

                            // Check if products list is empty
                            if (products.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 80,
                                      color: Colors.white30,
                                    ),
                                    SizedBox(height: 20),
                                    Text(
                                      'No Products Yet',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Tap + to add one',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: products.length,
                              itemBuilder: (BuildContext context, int index) {
                                Product product = products[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ProductDetailScreen(
                                                product: product),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 190,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: Image.network(
                                              product.imageUrl,
                                              fit: BoxFit.cover,
                                              height: 150,
                                              width: 150,
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return Container(
                                                  width: 150,
                                                  height: 150,
                                                  color: Colors.grey[300],
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  width: 150,
                                                  height: 150,
                                                  color: Colors.grey[300],
                                                  child: Icon(
                                                    Icons.image_not_supported,
                                                    color: Colors.grey[600],
                                                    size: 40,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          product.title,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontFamily: 'times new roman',
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'Price : \$${product.price.toString()}',
                                          style: TextStyle(
                                            color: Color.fromARGB(
                                                255, 255, 238, 0),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'times new roman',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          } else if (snapshot.hasError) {
                            return Text("${snapshot.error}");
                          }
                          // By default, show a loading spinner.
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                                SizedBox(height: 10.0),
                                Text(
                                  'Loading...',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 255, 255, 255),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 4,
                            width: 100,
                            color: Color.fromARGB(255, 0, 0, 0),
                            margin: EdgeInsets.only(top: 10, left: 20),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Recommended for you',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 0, 0, 0),
                                fontFamily: 'times new roman',
                              ),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: 16),
                            height: 350,
                            child: StreamBuilder<List<Product>>(
                              stream: productService.getProductsStream(),
                              builder: (BuildContext context,
                                  AsyncSnapshot<List<Product>> snapshot) {
                                if (snapshot.hasData) {
                                  List<Product> products = snapshot.data!;

                                  // Check if products list is empty
                                  if (products.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 60,
                                            color: Colors.black26,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'No Products Available',
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return GridView.builder(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.7,
                                    ),
                                    itemCount: products.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      Product product = products[index];
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ProductDetailScreen(
                                                      product: product),
                                            ),
                                          );
                                        },
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Image.network(
                                                  product.imageUrl,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context,
                                                      child, loadingProgress) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return Container(
                                                      color: Colors.grey[200],
                                                      child: Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[200],
                                                      child: Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        color: Colors.grey[400],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              product.title,
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              '\$${product.price.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: Color.fromARGB(
                                                    255, 200, 100, 0),
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                } else if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Error: ${snapshot.error}',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  );
                                }
                                return Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onPressed;

  const FilterButton({
    Key? key,
    required this.label,
    this.isSelected = false,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        isSelected ? Color.fromARGB(255, 0, 0, 0) : Colors.white;
    final textColor =
        isSelected ? Color.fromARGB(255, 255, 255, 255) : Colors.black;
    final borderColor = isSelected
        ? Color.fromARGB(255, 0, 0, 0)
        : Color.fromARGB(255, 0, 0, 0);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
