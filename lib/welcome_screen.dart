import 'package:flutter/material.dart';
import 'rounded_button.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0xff282828),
        body: Container(
        decoration:  BoxDecoration(
        image: DecorationImage(
        image: AssetImage("assets/images/bg9.jpg"),
        fit: BoxFit.fill),),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(child: Text("DIGAC",style:TextStyle(color: Colors.white,fontWeight: FontWeight.bold,fontSize: 24))),

                  SizedBox(height:24),
                  SizedBox(
                    height:48,
                    width:12,
                    child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      primary:Colors.amberAccent ),

                      child: Text('log in',style: TextStyle(fontSize: 18)),
                      onPressed: () {
                        Navigator.pushNamed(context, 'login_screen');
                      },
                    ),
                  ),
                  SizedBox(height:24),
                  SizedBox(
                    height:48,
                    width:12,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          primary: Colors.amberAccent
                      ),
                        onPressed: () {
                          Navigator.pushNamed(context, 'registration_screen');
                        }, child: Text('Register',style: TextStyle(fontSize: 18),),),
                  ),
                ]),
          ),
        ));
  }
}