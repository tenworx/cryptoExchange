import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/signup_screen.dart';
import 'package:flutter_application_1/welcome_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'login_screen.dart';
import 'tabs.dart';
import 'settings_page.dart';
import 'package:cnic_scanner/model/cnic_model.dart';
import 'package:image_picker/image_picker.dart';
import 'src/app_color.dart';
import 'src/custom_dialog.dart';
import 'package:cnic_scanner/cnic_scanner.dart';
import 'package:selfie_ocr_mtpl/selfie_ocr_mtpl.dart';

const double appBarHeight = 48.0;
const double appBarElevation = 1.0;

bool shortenOn = false;

List? marketListData;
Map? portfolioMap;
List? portfolioDisplay;
Map? totalPortfolioStats;

bool? isIOS;
String upArrow = "⬆";
String downArrow = "⬇";

int? lastUpdate;
Future<Null> getMarketData() async {
  int pages = 5;
  List tempMarketListData = [];

  Future<Null> _pullData(page) async {
    var response = await http.get(
        Uri.parse(
            "https://min-api.cryptocompare.com/data/top/mktcapfull?tsym=USD&limit=100" +
                "&page=" +
                page.toString()),
        headers: {"Accept": "application/json"});

    List rawMarketListData = new JsonDecoder().convert(response.body)["Data"];
    tempMarketListData.addAll(rawMarketListData);
  }

  List<Future> futures = [];
  for (int i = 0; i < pages; i++) {
    futures.add(_pullData(i));
  }
  await Future.wait(futures);

  marketListData = [];
  // Filter out lack of financial data
  for (Map coin in tempMarketListData) {
    if (coin.containsKey("RAW") && coin.containsKey("CoinInfo")) {
      marketListData!.add(coin);
    }
  }

  getApplicationDocumentsDirectory().then((Directory directory) async {
    File jsonFile = new File(directory.path + "/marketData.json");
    jsonFile.writeAsStringSync(json.encode(marketListData));
  });
  print("Got new market data.");

  lastUpdate = DateTime.now().millisecondsSinceEpoch;
}

SharedPreferences? prefs;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  prefs = await SharedPreferences.getInstance();
  await getApplicationDocumentsDirectory().then((Directory directory) async {
    File jsonFile = new File(directory.path + "/portfolio.json");
    if (jsonFile.existsSync()) {
      portfolioMap = json.decode(jsonFile.readAsStringSync());
    } else {
      jsonFile.createSync();
      jsonFile.writeAsStringSync("{}");
      portfolioMap = {};
    }
    if (portfolioMap == null) {
      portfolioMap = {};
    }
    jsonFile = new File(directory.path + "/marketData.json");
    if (jsonFile.existsSync()) {
      marketListData = json.decode(jsonFile.readAsStringSync());
    } else {
      jsonFile.createSync();
      jsonFile.writeAsStringSync("[]");
      marketListData = [];
      // getMarketData(); ?does this work?
    }
  });

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    String themeMode = "Automatic";
    bool darkOLED = false;

    if (prefs!.getBool("shortenOn") != null &&
        prefs!.getString("themeMode") != null) {
      shortenOn = prefs!.getBool("shortenOn")!;
      themeMode = prefs!.getString("themeMode")!;
      darkOLED = prefs!.getBool("darkOLED")!;
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: 'welcome_screen',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en', 'US'), // English, United States
        Locale('fr', 'FR'), // French, France
        Locale('es', 'ES'), // Spanish, Spain
      ],
      routes: {
        'welcome_screen': (context) => WelcomeScreen(),
        'registration_screen': (context) => RegistrationScreen(),
        'login_screen': (context) => LoginScreen(),
        'home_screen': (context) => TraceApp(themeMode, darkOLED)
      },
    );
  }
}

numCommaParse(numString) {
  if (shortenOn) {
    String str = num.parse(numString ?? "0")
        .round()
        .toString()
        .replaceAllMapped(new RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => "${m[1]},");
    List<String> strList = str.split(",");

    if (strList.length > 3) {
      return strList[0] +
          "." +
          strList[1].substring(0, 4 - strList[0].length) +
          "B";
    } else if (strList.length > 2) {
      return strList[0] +
          "." +
          strList[1].substring(0, 4 - strList[0].length) +
          "M";
    } else {
      return num.parse(numString ?? "0").toString().replaceAllMapped(
          new RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},");
    }
  }

  return num.parse(numString ?? "0").toString().replaceAllMapped(
      new RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},");
}

normalizeNum(num input) {
  if (input == null) {
    input = 0;
  }
  if (input >= 100000) {
    return numCommaParse(input.round().toString());
  } else if (input >= 1000) {
    return numCommaParse(input.toStringAsFixed(2));
  } else {
    return input.toStringAsFixed(6 - input.round().toString().length);
  }
}

normalizeNumNoCommas(num input) {
  if (input == null) {
    input = 0;
  }
  if (input >= 1000) {
    return input.toStringAsFixed(2);
  } else {
    return input.toStringAsFixed(6 - input.round().toString().length);
  }
}

class TraceApp extends StatefulWidget {
  TraceApp(this.themeMode, this.darkOLED);
  final themeMode;
  final darkOLED;

  @override
  TraceAppState createState() => new TraceAppState();
}

class TraceAppState extends State<TraceApp> {
  bool? darkEnabled;
  String? themeMode;
  bool? darkOLED;
  final HomePageController controller = Get.put(HomePageController());
  void savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("themeMode", themeMode!);
    prefs.setBool("shortenOn", shortenOn);
    prefs.setBool("darkOLED", darkOLED!);
  }

  toggleTheme() {
    switch (themeMode) {
      case "Automatic":
        themeMode = "Dark";
        break;
      case "Dark":
        themeMode = "Light";
        break;
      case "Light":
        themeMode = "Automatic";
        break;
    }
    handleUpdate();
    savePreferences();
  }

  setDarkEnabled() {
    switch (themeMode) {
      case "Automatic":
        int nowHour = new DateTime.now().hour;
        if (nowHour > 6 && nowHour < 20) {
          darkEnabled = false;
        } else {
          darkEnabled = true;
        }
        break;
      case "Dark":
        darkEnabled = true;
        break;
      case "Light":
        darkEnabled = false;
        break;
    }
    setNavBarColor();
  }

  handleUpdate() {
    setState(() {
      setDarkEnabled();
    });
  }

  switchOLED({state}) {
    setState(() {
      darkOLED = state ?? !darkOLED!;
    });
    setNavBarColor();
    savePreferences();
  }

  setNavBarColor() async {
    if (darkEnabled!) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarColor:
              darkOLED! ? darkThemeOLED.primaryColor : darkTheme.primaryColor));
    } else {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: lightTheme.primaryColor));
    }
  }

  final ThemeData lightTheme = new ThemeData(
    primarySwatch: Colors.yellow,
    brightness: Brightness.light,
    accentColor: Colors.yellowAccent[100],
    primaryColor: Colors.white,
    primaryColorLight: Colors.yellow[700],
    dividerColor: Colors.grey[200],
    bottomAppBarColor: Colors.grey[200],
    buttonColor: Colors.yellow[700],
    iconTheme: new IconThemeData(color: Colors.white),
    primaryIconTheme: new IconThemeData(color: Colors.black),
    accentIconTheme: new IconThemeData(color: Colors.yellow[700]),
    disabledColor: Colors.grey[500],
    textSelectionTheme:
        TextSelectionThemeData(selectionHandleColor: Colors.yellow[700]),
  );

  final ThemeData darkTheme = new ThemeData(
    primarySwatch: Colors.yellow,
    brightness: Brightness.dark,
    accentColor: Colors.yellowAccent[100],
    primaryColor: Color.fromRGBO(50, 50, 57, 1.0),
    primaryColorLight: Colors.yellowAccent[100],
    buttonColor: Colors.yellowAccent[100],
    iconTheme: new IconThemeData(color: Colors.white),
    accentIconTheme: new IconThemeData(color: Colors.yellowAccent[100]),
    cardColor: Color.fromRGBO(55, 55, 55, 1.0),
    dividerColor: Color.fromRGBO(60, 60, 60, 1.0),
    bottomAppBarColor: Colors.black26,
    textSelectionTheme:
        TextSelectionThemeData(selectionHandleColor: Colors.yellowAccent[100]),
  );

  final ThemeData darkThemeOLED = new ThemeData(
    brightness: Brightness.dark,
    accentColor: Colors.yellowAccent[100],
    primaryColor: Color.fromRGBO(5, 5, 5, 1.0),
    backgroundColor: Colors.black,
    canvasColor: Colors.black,
    primaryColorLight: Colors.yellowAccent[300],
    buttonColor: Colors.yellowAccent[100],
    accentIconTheme: new IconThemeData(color: Colors.yellowAccent[300]),
    cardColor: Color.fromRGBO(16, 16, 16, 1.0),
    dividerColor: Color.fromRGBO(20, 20, 20, 1.0),
    bottomAppBarColor: Color.fromRGBO(19, 19, 19, 1.0),
    dialogBackgroundColor: Colors.black,
    iconTheme: new IconThemeData(color: Colors.white),
    textSelectionTheme:
        TextSelectionThemeData(selectionHandleColor: Colors.yellowAccent[100]),
  );

  @override
  void initState() {
    super.initState();
    themeMode = widget.themeMode ?? "Automatic";
    darkOLED = widget.darkOLED ?? false;
    setDarkEnabled();
  }

  @override
  Widget build(BuildContext context) {
    isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    if (isIOS!) {
      upArrow = "↑";
      downArrow = "↓";
    }

    return new MaterialApp(
      debugShowCheckedModeBanner: false,
      color: darkEnabled!
          ? darkOLED!
              ? darkThemeOLED.primaryColor
              : darkTheme.primaryColor
          : lightTheme.primaryColor,
      title: "DIGAC",
      home: new Tabs(
        savePreferences: savePreferences,
        toggleTheme: toggleTheme,
        handleUpdate: handleUpdate,
        darkEnabled: darkEnabled!,
        themeMode: themeMode!,
        switchOLED: switchOLED,
        darkOLED: darkOLED!,
      ),
      theme: darkEnabled!
          ? darkOLED!
              ? darkThemeOLED
              : darkTheme
          : lightTheme,
      routes: <String, WidgetBuilder>{
        "/settings": (BuildContext context) => new SettingsPage(
              savePreferences: savePreferences,
              toggleTheme: toggleTheme,
              darkEnabled: darkEnabled!,
              themeMode: themeMode!,
              switchOLED: switchOLED,
              darkOLED: darkOLED!,
            ),
      },
    );
  }
}

class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              height: 60,
            ),
            Container(
              width: 350,
              height: 150,
              child: GestureDetector(
                onTap: () {
                  print("hello inside gesture detector");
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => Liveness()));
                },
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  color: Colors.grey.shade900,
                  child: Column(
                    // mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      SizedBox(
                        height: 2,
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 130),
                        child: Text(
                          "Welcome to DIGAC Trade",
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                      ),
                      SizedBox(
                        height: 8,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 90),
                        child: Text(
                          'Finish account setup > ',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class HomePageController extends GetxController {
  // final count = 0.obs;
  RxBool? darkEnabled;
  // increment() => count.value++;
}

class Liveness extends StatefulWidget {
  @override
  _LivenessState createState() => _LivenessState();
}

class LivenessController extends GetxController {
  RxString _platformVersion = 'Unknown'.obs;
  RxString platformVersion = ''.obs;
  // final count = 0.obs;
  // increment() => count.value++;
}

class _LivenessState extends State<Liveness> {
  // String _platformVersion = 'Unknown';
  final LivenessController controller = Get.put(LivenessController());
  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    //  String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      controller.platformVersion.value =
          await FlutterTestSelfiecapture.platformVersion;
    } on PlatformException {
      controller.platformVersion.value = 'Failed to get platform version.';
    }
    if (!mounted) return;
    controller._platformVersion.value = controller.platformVersion.value;
  }

  FirebaseStorage storage = FirebaseStorage.instance;
  File? _image;

  final uid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> addImageToFirebaseRD(image) async {
    final databaseReference = FirebaseDatabase.instance.reference();
    if (uid.toString() != "" && image != null) {
      print("s1");
      print(image.toString());
      databaseReference.child(uid).update({'profile': image.path.toString()});
      print("db updated success");
      Future.delayed(const Duration(milliseconds: 1000), () {
        AwesomeDialog(
          context: context,
          animType: AnimType.BOTTOMSLIDE,
          headerAnimationLoop: false,
          dialogType: DialogType.SUCCES,
          showCloseIcon: true,
          title: 'Success',
          desc: 'Liveness Detected Successfully',
          btnOkOnPress: () {
            debugPrint('OnClcik');
          },
          btnOkIcon: Icons.check_circle,
          onDismissCallback: (type) {
            debugPrint('Dialog Dissmiss from callback $type');
          },
        ).show();
      });
    }
  }

  Future<void> addImageToFirebase(image) async {
    //CreateRefernce to path.

    FirebaseStorage.instance
        .ref(uid + "/")
        .putFile(File(image))
        .then((TaskSnapshot taskSnapshot) {
      if (taskSnapshot.state == TaskState.success) {
        print("Image uploaded Successful");
        final databaseReference = FirebaseDatabase.instance.reference();

        // Get Image URL Now
        taskSnapshot.ref.getDownloadURL().then((imageURL) {
          print("Image Download URL is $imageURL");
          if (uid.toString() != "" && imageURL != null) {
            databaseReference.child(uid).update({'profile': imageURL});
          }
        });
      }
      Future.delayed(const Duration(milliseconds: 1000), () {
        AwesomeDialog(
          context: context,
          animType: AnimType.BOTTOMSLIDE,
          headerAnimationLoop: false,
          dialogType: DialogType.SUCCES,
          showCloseIcon: true,
          title: 'Success',
          desc: 'Liveness Detected Successfully',
          btnOkOnPress: () {
            debugPrint('OnClcik');
          },
          btnOkIcon: Icons.check_circle,
          onDismissCallback: (type) {
            debugPrint('Dialog Dissmiss from callback $type');
          },
        ).show();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('KYC'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, false);
            },
          ),
          backgroundColor: Color(0xffFFC300),
        ),
        body: Container(
          margin: EdgeInsets.only(bottom: 195),
          decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/images/bh13.jpg"),
                fit: BoxFit.fitWidth),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: 260),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(primary: Color(0xffFFC300)),
                    onPressed: () async {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => ScanCnicPage()));
                    },
                    child: Text("Scan CNC"),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(primary: Color(0xffFFC300)),
                    onPressed: () async {
                      Future<String> filepath =
                          FlutterTestSelfiecapture.detectLiveliness(
                              "KYC", "msgBlinkEye");
                      print(filepath.toString());
                      dynamic tempFile = filepath.toString();
                      print(tempFile);
                      tempFile = await tempFile
                          .copy('storage/emulated/0/Pictures/tempname.jpg');
                      print("done");

                      print(
                          tempFile); //  final databaseReference = FirebaseDatabase.instance.reference();
                      print("done");
                      //
                      //   // Get Image URL Now
                      //   taskSnapshot.ref.getDownloadURL().then(
                      //           (imageURL) {
                      //         print("Image Download URL is $imageURL");
                      //         if (uid.toString() != "" && imageURL != null) {
                      //           databaseReference.child(uid).update({
                      //             'profile': imageURL
                      //           });
                      //         }
                      //       });
                      // }
                      // Future.delayed(const Duration(milliseconds: 1000), () {
                      //   AwesomeDialog(
                      //     context: context,
                      //     animType: AnimType.BOTTOMSLIDE,
                      //     headerAnimationLoop: false,
                      //     dialogType: DialogType.SUCCES,
                      //     showCloseIcon: true,
                      //     title: 'Success',
                      //     desc:
                      //     'Liveness Detected Successfully',
                      //     btnOkOnPress: () {
                      //       debugPrint('OnClcik');
                      //     },
                      //     btnOkIcon: Icons.check_circle,
                      //     onDissmissCallback: (type) {
                      //       debugPrint('Dialog Dissmiss from callback $type');
                      //     },
                      //   ).show();
                      // });
                      // }
                      // );
                      //  addImageToFirebaseRD(filepath);
                    },
                    child: Text("Detect Liveness"),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScanCnicPage extends StatefulWidget {
  @override
  _ScanCnicPageState createState() => _ScanCnicPageState();
}

class Scancnic_Controller extends GetxController {
  Rx<CnicModel> _cnicModel = CnicModel().obs;
  Rx<TextEditingController> nameTEController = TextEditingController().obs,
      cnicTEController = TextEditingController().obs,
      dobTEController = TextEditingController().obs,
      doiTEController = TextEditingController().obs,
      doeTEController = TextEditingController().obs;

// final count = 0.obs;
  // increment() => count.value++;
}

class _ScanCnicPageState extends State<ScanCnicPage> {
  final databaseReference = FirebaseDatabase.instance.reference();

  final uid = FirebaseAuth.instance.currentUser!.uid;
  final Scancnic_Controller controller = Get.put(Scancnic_Controller());
  // TextEditingController nameTEController = TextEditingController(),
  //     cnicTEController = TextEditingController(),
  //     dobTEController = TextEditingController(),
  //     doiTEController = TextEditingController(),
  //     doeTEController = TextEditingController();

//  CnicModel _cnicModel = CnicModel();
  void updateData(username, cnic, dob, doc_issue, doc_expiry) {
    if (uid.toString() != "") {
      databaseReference.child(uid).update({
        'username': username,
        'cnic': cnic,
        'dob': dob,
        'doc_issue': doc_issue,
        'doc_exiry': doc_expiry
      });
    }
  }

  void createData(username, cnic, dob, doc_issue, doc_expiry) {
    if (uid.toString() != "") {
      databaseReference.child(uid).set({
        'username': username,
        'cnic': cnic,
        'dob': dob,
        'doc_issue': doc_issue,
        'doc_exiry': doc_expiry
      });

      AwesomeDialog(
        context: context,
        animType: AnimType.BOTTOMSLIDE,
        headerAnimationLoop: false,
        dialogType: DialogType.SUCCES,
        showCloseIcon: true,
        title: 'Success',
        desc: 'CNIC Scanned Successfully',
        btnOkOnPress: () {
          debugPrint('OnClcik');
        },
        btnOkIcon: Icons.check_circle,
        onDismissCallback: (type) {
          debugPrint('Dialog Dissmiss from callback $type');
        },
      ).show();
      Future.delayed(const Duration(milliseconds: 1000), () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => Liveness()));
      });
    }
  }

  Future<void> scanCnic(ImageSource imageSource) async {
    print("user logged in id is " + uid);
    CnicModel cnicModel =
        await CnicScanner().scanImage(imageSource: imageSource);
    if (cnicModel == null) return;
    controller._cnicModel.value = cnicModel;
    controller.nameTEController.value.text =
        controller._cnicModel.value.cnicHolderName;
    controller.cnicTEController.value.text =
        controller._cnicModel.value.cnicNumber;
    controller.dobTEController.value.text =
        controller._cnicModel.value.cnicHolderDateOfBirth;
    controller.doiTEController.value.text =
        controller._cnicModel.value.cnicIssueDate;
    controller.doeTEController.value.text =
        controller._cnicModel.value.cnicExpiryDate;
    createData(
        controller.nameTEController.value.text,
        controller.cnicTEController.value.text,
        controller.dobTEController.value.text,
        controller.doiTEController.value.text,
        controller.doeTEController.value.text);
    print("Data created successfully");
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
          backgroundColor: Color(0xff282828),
          body: Container(
            margin:
                const EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 18,
                ),
                Text('Enter ID Card Details',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 23.0,
                        fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 5,
                ),
                Text('To verify your Account, please enter your CNIC details.',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w500)),
                SizedBox(
                  height: 35,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(0),
                    shrinkWrap: true,
                    children: [
                      _dataField(
                          text: 'Name',
                          textEditingController:
                              controller.nameTEController.value),
                      _cnicField(
                          textEditingController:
                              controller.cnicTEController.value),
                      _dataField(
                          text: 'Date of Birth',
                          textEditingController:
                              controller.dobTEController.value),
                      _dataField(
                          text: 'Date of Card Issue',
                          textEditingController:
                              controller.doiTEController.value),
                      _dataField(
                          text: 'Date of Card Expire',
                          textEditingController:
                              controller.doeTEController.value),
                      SizedBox(
                        height: 20,
                      ),
                      _getScanCNICBtn(),
                      SizedBox(
                        height: 20,
                      ),
                      _getBackBtn(),
                    ],
                  ),
                )
              ],
            ),
          ),
        ));
  }

  Widget _cnicField({required TextEditingController textEditingController}) {
    return Card(
      elevation: 7,
      margin: const EdgeInsets.only(top: 2.0, bottom: 5.0),
      child: Container(
        margin:
            const EdgeInsets.only(top: 2.0, bottom: 1.0, left: 0.0, right: 0.0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                height: 45,
                margin: const EdgeInsets.only(left: 3.0, right: 7.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [
                        // const Color(kDeepDarkGreenColor),
                        // const Color(kDarkGreenColor),
                        // const Color(kGradientGreyColor),
                        Colors.yellowAccent,
                        Color(0xfff4d46e),
                        Colors.yellow,
                      ],
                      stops: [
                        0.0,
                        0.5,
                        1.0
                      ],
                      tileMode: TileMode.mirror,
                      end: Alignment.bottomCenter,
                      begin: Alignment.topRight),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CNIC Number',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Row(
                    children: [
                      Image.asset("assets/images/cnic.png",
                          width: 40, height: 30),
                      Expanded(
                        child: TextField(
                          controller: textEditingController,
                          decoration: InputDecoration(
                            hintText: '41000-0000000-0',
                            hintStyle: TextStyle(color: Color(kLightGreyColor)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.only(left: 5.0),
                          ),
                          style: TextStyle(
                              color: Color(kDarkGreyColor),
                              fontWeight: FontWeight.bold),
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.left,
                        ),
                      )
                    ],
                  )
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dataField(
      {required String text,
      required TextEditingController textEditingController}) {
    return Card(
        shadowColor: Color(kShadowColor),
        elevation: 5,
        margin: const EdgeInsets.only(
          top: 10,
          bottom: 5,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Icon(
                (text == "Name") ? Icons.person : Icons.date_range,
                color: Colors.black,
                size: 17,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 15.0, top: 5, bottom: 3),
                    child: Text(
                      text.toUpperCase(),
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 15.0, bottom: 5),
                    child: TextField(
                      controller: textEditingController,
                      decoration: InputDecoration(
                        hintText: (text == "Name") ? "User Name" : 'DD/MM/YYYY',
                        border: InputBorder.none,
                        isDense: true,
                        hintStyle: TextStyle(
                            color: Color(kLightGreyColor),
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                        contentPadding: EdgeInsets.all(0),
                      ),
                      style: TextStyle(
                          color: Color(kDarkGreyColor),
                          fontWeight: FontWeight.bold),
                      textInputAction: TextInputAction.done,
                      keyboardType: (text == "Name")
                          ? TextInputType.text
                          : TextInputType.number,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ));
  }

  Widget _getScanCNICBtn() {
    return ElevatedButton(
      // elevation: 5,
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      onPressed: () {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return CustomDialogBox(onCameraBTNPressed: () {
                scanCnic(ImageSource.camera);
              }, onGalleryBTNPressed: () {
                scanCnic(ImageSource.gallery);
              });
            });
      },
      // textColor: Colors.white,
      // padding: EdgeInsets.all(0.0),
      child: Container(
        alignment: Alignment.center,
        width: 500,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(10.0)),
          gradient: LinearGradient(colors: <Color>[
            Colors.yellowAccent,
            Color(0xfff4d46e),
            Colors.yellow,
          ]),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Text('Scan CNIC', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _getBackBtn() {
    return ElevatedButton(
      // elevation: 5,
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      onPressed: () {
        Navigator.of(context).pop();
      },
      // textColor: Colors.white,
      // padding: EdgeInsets.all(0.0),
      child: Container(
        alignment: Alignment.center,
        width: 500,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(10.0)),
          gradient: LinearGradient(colors: <Color>[
            Colors.yellowAccent,
            Color(0xfff4d46e),
            Colors.yellow,
          ]),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Text('Back', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
