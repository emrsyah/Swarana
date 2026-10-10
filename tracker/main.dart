import 'package:flutter/material.dart';
import '../lib/ux_task_kit.dart';
// import 'package:posthog_flutter/posthog_flutter.dart';

// Optional: send everything to PostHog instead of the debug console.
// class PostHogSink implements UxEventSink {
//   @override
//   void send(String event, Map<String, Object?> props) {
//     Posthog().capture(
//       eventName: event,
//       properties: {
//         for (final e in props.entries)
//           if (e.value != null) e.key: e.value!,
//       },
//     );
//   }
// }

final navKey = GlobalKey<NavigatorState>();

void main() {
  UxTestController.instance.configure(
    participantId: 'p-001', // e.g. from a deep link: myapp://test?pid=p-001
    navigatorKey: navKey,
    // sink: PostHogSink(),
    tasks: const [
      UxTask(
        id: 'find_profile',
        title: 'Find your profile',
        instruction: 'Open the page where you can see your own profile.',
        startRoute: '/',
        successRoute: '/profile', // auto-finishes on this screen
        expectedPath: ['/', '/profile'],
        timeLimit: Duration(minutes: 2),
      ),
      UxTask(
        id: 'book_slot',
        title: 'Book a slot',
        instruction: 'Book any available time slot for tomorrow.',
        startRoute: '/',
        successSignal: 'booking_confirmed', // finishes when app signals it
        expectedPath: ['/', '/schedule'],
        timeLimit: Duration(minutes: 3),
      ),
    ],
  );
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
      navigatorObservers: [UxNavigatorObserver()],
      builder: (context, child) => UxTestHarness(child: child!),
      routes: {
        '/': (_) => const HomePage(),
        '/profile': (_) => const SimplePage(title: 'Profile'),
        '/schedule': (_) => const SchedulePage(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: ListView(children: [
          ListTile(
            title: const Text('Profile'),
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
          ListTile(
            title: const Text('Schedule'),
            onTap: () => Navigator.pushNamed(context, '/schedule'),
          ),
        ]),
      );
}

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Schedule')),
        body: Center(
          child: FilledButton(
            onPressed: () {
              // ...your real booking logic...
              UxTestController.instance.signal('booking_confirmed');
            },
            child: const Text('Book 2:00 PM'),
          ),
        ),
      );
}

class SimplePage extends StatelessWidget {
  const SimplePage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)));
}
