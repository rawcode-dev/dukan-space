import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'database/db_provider.dart';
import 'database/inventory_repository.dart';
import 'services/excel_parser_service.dart';
import 'services/search_service.dart';
import 'viewmodels/import_viewmodel.dart';
import 'viewmodels/inventory_viewmodel.dart';
import 'viewmodels/search_viewmodel.dart';
import 'views/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DukanSpaceApp());
}

class DukanSpaceApp extends StatelessWidget {
  const DukanSpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dbProvider = DBProvider.instance;
    final inventoryRepo = InventoryRepository(dbProvider: dbProvider);
    final searchService = SearchService(repository: inventoryRepo);
    final excelParserService = ExcelParserService();

    return MultiProvider(
      providers: [
        Provider<DBProvider>.value(value: dbProvider),
        Provider<InventoryRepository>.value(value: inventoryRepo),
        Provider<SearchService>.value(value: searchService),
        Provider<ExcelParserService>.value(value: excelParserService),
        ChangeNotifierProvider<SearchViewModel>(
          create: (_) => SearchViewModel(searchService: searchService),
        ),
        ChangeNotifierProvider<InventoryViewModel>(
          create: (_) => InventoryViewModel(repository: inventoryRepo),
        ),
        ChangeNotifierProvider<ImportViewModel>(
          create: (_) => ImportViewModel(
            repository: inventoryRepo,
            parserService: excelParserService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'DukanSpace',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F766E), // Deep Teal (high contrast for shops)
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
        ),
        home: const MainNavigationScreen(),
      ),
    );
  }
}

