// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [AboutScreen]
class AboutRoute extends PageRouteInfo<void> {
  const AboutRoute({List<PageRouteInfo>? children})
    : super(AboutRoute.name, initialChildren: children);

  static const String name = 'AboutRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AboutScreen();
    },
  );
}

/// generated route for
/// [BusyScreen]
class BusyRoute extends PageRouteInfo<void> {
  const BusyRoute({List<PageRouteInfo>? children})
    : super(BusyRoute.name, initialChildren: children);

  static const String name = 'BusyRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const BusyScreen();
    },
  );
}

/// generated route for
/// [FavouritesScreen]
class FavouritesRoute extends PageRouteInfo<void> {
  const FavouritesRoute({List<PageRouteInfo>? children})
    : super(FavouritesRoute.name, initialChildren: children);

  static const String name = 'FavouritesRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const FavouritesScreen();
    },
  );
}

/// generated route for
/// [InfoScreen]
class InfoRoute extends PageRouteInfo<InfoRouteArgs> {
  InfoRoute({Key? key, bool rules = false, List<PageRouteInfo>? children})
    : super(
        InfoRoute.name,
        args: InfoRouteArgs(key: key, rules: rules),
        rawQueryParams: {'rules': rules},
        initialChildren: children,
      );

  static const String name = 'InfoRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<InfoRouteArgs>(
        orElse: () => InfoRouteArgs(rules: queryParams.getBool('rules', false)),
      );
      return InfoScreen(key: args.key, rules: args.rules);
    },
  );
}

class InfoRouteArgs {
  const InfoRouteArgs({this.key, this.rules = false});

  final Key? key;

  final bool rules;

  @override
  String toString() {
    return 'InfoRouteArgs{key: $key, rules: $rules}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! InfoRouteArgs) return false;
    return key == other.key && rules == other.rules;
  }

  @override
  int get hashCode => key.hashCode ^ rules.hashCode;
}

/// generated route for
/// [InvoicesScreen]
class InvoicesRoute extends PageRouteInfo<void> {
  const InvoicesRoute({List<PageRouteInfo>? children})
    : super(InvoicesRoute.name, initialChildren: children);

  static const String name = 'InvoicesRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const InvoicesScreen();
    },
  );
}

/// generated route for
/// [LessonDetailScreen]
class LessonDetailRoute extends PageRouteInfo<LessonDetailRouteArgs> {
  LessonDetailRoute({
    Key? key,
    required int lessonId,
    List<PageRouteInfo>? children,
  }) : super(
         LessonDetailRoute.name,
         args: LessonDetailRouteArgs(key: key, lessonId: lessonId),
         rawPathParams: {'id': lessonId},
         initialChildren: children,
       );

  static const String name = 'LessonDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<LessonDetailRouteArgs>(
        orElse: () => LessonDetailRouteArgs(lessonId: pathParams.getInt('id')),
      );
      return LessonDetailScreen(key: args.key, lessonId: args.lessonId);
    },
  );
}

class LessonDetailRouteArgs {
  const LessonDetailRouteArgs({this.key, required this.lessonId});

  final Key? key;

  final int lessonId;

  @override
  String toString() {
    return 'LessonDetailRouteArgs{key: $key, lessonId: $lessonId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LessonDetailRouteArgs) return false;
    return key == other.key && lessonId == other.lessonId;
  }

  @override
  int get hashCode => key.hashCode ^ lessonId.hashCode;
}

/// generated route for
/// [LocationScreen]
class LocationRoute extends PageRouteInfo<void> {
  const LocationRoute({List<PageRouteInfo>? children})
    : super(LocationRoute.name, initialChildren: children);

  static const String name = 'LocationRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LocationScreen();
    },
  );
}

/// generated route for
/// [LoginScreen]
class LoginRoute extends PageRouteInfo<void> {
  const LoginRoute({List<PageRouteInfo>? children})
    : super(LoginRoute.name, initialChildren: children);

  static const String name = 'LoginRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LoginScreen();
    },
  );
}

/// generated route for
/// [MainScreen]
class MainRoute extends PageRouteInfo<void> {
  const MainRoute({List<PageRouteInfo>? children})
    : super(MainRoute.name, initialChildren: children);

  static const String name = 'MainRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MainScreen();
    },
  );
}

/// generated route for
/// [MembershipsScreen]
class MembershipsRoute extends PageRouteInfo<void> {
  const MembershipsRoute({List<PageRouteInfo>? children})
    : super(MembershipsRoute.name, initialChildren: children);

  static const String name = 'MembershipsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MembershipsScreen();
    },
  );
}

/// generated route for
/// [MoreScreen]
class MoreRoute extends PageRouteInfo<void> {
  const MoreRoute({List<PageRouteInfo>? children})
    : super(MoreRoute.name, initialChildren: children);

  static const String name = 'MoreRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MoreScreen();
    },
  );
}

/// generated route for
/// [MyLessonsScreen]
class MyLessonsRoute extends PageRouteInfo<void> {
  const MyLessonsRoute({List<PageRouteInfo>? children})
    : super(MyLessonsRoute.name, initialChildren: children);

  static const String name = 'MyLessonsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MyLessonsScreen();
    },
  );
}

/// generated route for
/// [NewsScreen]
class NewsRoute extends PageRouteInfo<NewsRouteArgs> {
  NewsRoute({
    Key? key,
    bool notifications = false,
    List<PageRouteInfo>? children,
  }) : super(
         NewsRoute.name,
         args: NewsRouteArgs(key: key, notifications: notifications),
         rawQueryParams: {'notifications': notifications},
         initialChildren: children,
       );

  static const String name = 'NewsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<NewsRouteArgs>(
        orElse: () => NewsRouteArgs(
          notifications: queryParams.getBool('notifications', false),
        ),
      );
      return NewsScreen(key: args.key, notifications: args.notifications);
    },
  );
}

class NewsRouteArgs {
  const NewsRouteArgs({this.key, this.notifications = false});

  final Key? key;

  final bool notifications;

  @override
  String toString() {
    return 'NewsRouteArgs{key: $key, notifications: $notifications}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! NewsRouteArgs) return false;
    return key == other.key && notifications == other.notifications;
  }

  @override
  int get hashCode => key.hashCode ^ notifications.hashCode;
}

/// generated route for
/// [ProfileScreen]
class ProfileRoute extends PageRouteInfo<void> {
  const ProfileRoute({List<PageRouteInfo>? children})
    : super(ProfileRoute.name, initialChildren: children);

  static const String name = 'ProfileRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProfileScreen();
    },
  );
}

/// generated route for
/// [ScheduleScreen]
class ScheduleRoute extends PageRouteInfo<void> {
  const ScheduleRoute({List<PageRouteInfo>? children})
    : super(ScheduleRoute.name, initialChildren: children);

  static const String name = 'ScheduleRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ScheduleScreen();
    },
  );
}

/// generated route for
/// [SyncSettingsScreen]
class SyncSettingsRoute extends PageRouteInfo<void> {
  const SyncSettingsRoute({List<PageRouteInfo>? children})
    : super(SyncSettingsRoute.name, initialChildren: children);

  static const String name = 'SyncSettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SyncSettingsScreen();
    },
  );
}
