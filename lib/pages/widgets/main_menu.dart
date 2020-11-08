import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MainMenuDrawer extends StatefulWidget {
  MainMenuDrawer({Key key}) : super(key: key);

  _MainMenuDrawerState createState() => _MainMenuDrawerState();
}

class _MainMenuDrawerState extends State<MainMenuDrawer> {

  @override
  void initState() {
    super.initState();
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints.expand(height: 100),
          alignment: Alignment.center,
          // child: Image.asset(
          //   "assets/images/logo.png",
          //   fit: BoxFit.cover,
          // ),
        ),
        Container(
          margin: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: Color.fromRGBO(163, 163, 163, 1)),
        ),
        Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              linkMenuDrawer(context, 'Análises', () {
                Navigator.pushNamed(context, '/lines');
              }, icon: Icons.settings_backup_restore),
              linkMenuDrawer(context, 'Avaliar', () {
                //LaunchReview.launch();
              }, icon: Icons.star, color: Color(0xffFFBF00)),
              linkMenuDrawer(context, 'FAQ', () {
                Navigator.pushNamed(context, '/faq');
              }, icon: Icons.help),
              linkMenuDrawer(context, 'Sair', () {
                SystemNavigator.pop();
              }, icon: Icons.exit_to_app, color: Color(0xffff4000)),
            ]),
        Container(
          margin: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: Color.fromRGBO(163, 163, 163, 1)),
        )
      ],
    );
  }
}

Widget linkMenuDrawer(BuildContext context, String title, Function onPressed,
    {IconData icon, Color color}) {
  if (icon == null) {
    return InkWell(
      onTap: onPressed,
      splashColor: Theme.of(context).primaryColorDark,
      child: Container(
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          width: double.infinity,
          child: Text(
            title,
            style: TextStyle(fontSize: 18.0),
          )),
    );
  } else {
    return InkWell(
      onTap: onPressed,
      splashColor: Theme.of(context).primaryColorDark,
      child: Container(
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          width: double.infinity,
          child: Row(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(right: 5),
                child: Icon(icon, color: color),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 18.0),
              )
            ],
          )),
    );
  }
}
