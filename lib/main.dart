import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MsaRecordAdapter());
  await Hive.openBox<MsaRecord>('msan_records');
  runApp(const MyApp());
}

// ======================== Hive Model ========================
@HiveType(typeId: 0)
class MsaRecord extends HiveObject {
  @HiveField(0)
  String areaCode;
  @HiveField(1)
  String phoneNumber;
  @HiveField(2)
  String msanCode;
  @HiveField(3)
  String frame;
  @HiveField(4)
  String shelf;
  @HiveField(5)
  String slot;
  @HiveField(6)
  String portNumber;
  @HiveField(7)
  String portType;
  @HiveField(8)
  String voiceStatus;
  @HiveField(9)
  String dataStatus;
  @HiveField(10)
  String operator;

  MsaRecord({
    required this.areaCode,
    required this.phoneNumber,
    required this.msanCode,
    required this.frame,
    required this.shelf,
    required this.slot,
    required this.portNumber,
    required this.portType,
    required this.voiceStatus,
    required this.dataStatus,
    required this.operator,
  });

  Map<String, String> toMap() => {
    'Area Code': areaCode,
    'Phone Number': phoneNumber,
    'MSAN Code': msanCode,
    'Frame': frame,
    'Shelf': shelf,
    'Slot': slot,
    'Port number': portNumber,
    'Port type': portType,
    'Voice Status': voiceStatus,
    'Data Status': dataStatus,
    'Operator': operator,
  };
}

// ======================== Manual Hive Adapter ========================
class MsaRecordAdapter extends TypeAdapter<MsaRecord> {
  @override
  final int typeId = 0;

  @override
  MsaRecord read(BinaryReader reader) {
    return MsaRecord(
      areaCode: reader.readString(),
      phoneNumber: reader.readString(),
      msanCode: reader.readString(),
      frame: reader.readString(),
      shelf: reader.readString(),
      slot: reader.readString(),
      portNumber: reader.readString(),
      portType: reader.readString(),
      voiceStatus: reader.readString(),
      dataStatus: reader.readString(),
      operator: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, MsaRecord obj) {
    writer.writeString(obj.areaCode);
    writer.writeString(obj.phoneNumber);
    writer.writeString(obj.msanCode);
    writer.writeString(obj.frame);
    writer.writeString(obj.shelf);
    writer.writeString(obj.slot);
    writer.writeString(obj.portNumber);
    writer.writeString(obj.portType);
    writer.writeString(obj.voiceStatus);
    writer.writeString(obj.dataStatus);
    writer.writeString(obj.operator);
  }
}

// ======================== App ========================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MSAN Port Finder',
      locale: Locale(HomePage.localeCode),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        fontFamily: 'Poppins',
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B4AA),
          primary: const Color(0xFF00B4AA),
          secondary: const Color(0xFF6C63FF),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  static String localeCode = 'en';
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  MsaRecord? _result;
  String? _cabinetType;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _cabinetType = 'HUAWEI';

    _phoneController.addListener(_onPhoneNumberChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBundledDataIfEmpty());
  }

  void _onPhoneNumberChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  void _performSearch() {
    final input = _phoneController.text.trim();
    if (input.isEmpty) {
      setState(() => _result = null);
      _animationController.reverse();
      return;
    }

    final box = Hive.box<MsaRecord>('msan_records');
    MsaRecord? found;
    for (var record in box.values) {
      if (record.phoneNumber == input) {
        found = record;
        break;
      }
    }
    setState(() => _result = found);
    if (found != null) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  // Load bundled Excel data if the box is empty
  Future<void> _loadBundledDataIfEmpty() async {
    final box = Hive.box<MsaRecord>('msan_records');
    if (box.isNotEmpty) return;

    try {
      final ByteData data = await rootBundle.load('assets/msan_data.xlsx');
      final bytes = data.buffer.asUint8List();
      final excel = Excel.decodeBytes(bytes);
      int count = 0;

      for (var sheet in excel.tables.keys) {
        final rows = excel.tables[sheet]!.rows;
        if (rows.isEmpty) continue;

        final headers = rows[0]
            .map((cell) => cell?.value?.toString().trim() ?? '')
            .toList();

        final expected = [
          'Area Code',
          'Phone Number',
          'MSAN Code',
          'Frame',
          'Shelf',
          'Slot',
          'Port number',
          'Port type',
          'Voice Status',
          'Data Status',
          'Operator',
        ];

        final indices = expected.map((col) => headers.indexWhere((h) =>
        h.toLowerCase().replaceAll(' ', '') ==
            col.toLowerCase().replaceAll(' ', ''))).toList();

        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          final record = MsaRecord(
            areaCode: _getCellValue(row, indices[0]),
            phoneNumber: _getCellValue(row, indices[1]),
            msanCode: _getCellValue(row, indices[2]),
            frame: _getCellValue(row, indices[3]),
            shelf: _getCellValue(row, indices[4]),
            slot: _getCellValue(row, indices[5]),
            portNumber: _getCellValue(row, indices[6]),
            portType: _getCellValue(row, indices[7]),
            voiceStatus: _getCellValue(row, indices[8]),
            dataStatus: _getCellValue(row, indices[9]),
            operator: _getCellValue(row, indices[10]),
          );
          if (record.phoneNumber.isNotEmpty) {
            await box.add(record);
            count++;
          }
        }
      }

      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(HomePage.localeCode == 'en'
                ? 'Bundled data loaded ($count records)'
                : 'تم تحميل البيانات المضمنة ($count سجل)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(HomePage.localeCode == 'en'
                ? 'Failed to load bundled data: $e'
                : 'فشل تحميل البيانات المضمنة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getCellValue(List<Data?> row, int index) {
    if (index == -1 || index >= row.length) return '';
    final value = row[index]?.value;
    return value?.toString() ?? '';
  }

  void _toggleLanguage() {
    setState(() {
      HomePage.localeCode = HomePage.localeCode == 'en' ? 'ar' : 'en';
    });
  }

  Future<void> _importFiles() async {
    FilePickerResult? files = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (files == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final box = Hive.box<MsaRecord>('msan_records');
      await box.clear();
      int count = 0;

      for (var file in files.files) {
        final bytes = File(file.path!).readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);

        for (var sheet in excel.tables.keys) {
          final rows = excel.tables[sheet]!.rows;
          if (rows.isEmpty) continue;

          final headers = rows[0]
              .map((cell) => cell?.value?.toString().trim() ?? '')
              .toList();

          final expected = [
            'Area Code',
            'Phone Number',
            'MSAN Code',
            'Frame',
            'Shelf',
            'Slot',
            'Port number',
            'Port type',
            'Voice Status',
            'Data Status',
            'Operator',
          ];

          final indices = expected.map((col) => headers.indexWhere((h) =>
          h.toLowerCase().replaceAll(' ', '') ==
              col.toLowerCase().replaceAll(' ', ''))).toList();

          for (int i = 1; i < rows.length; i++) {
            final row = rows[i];
            final record = MsaRecord(
              areaCode: _getCellValue(row, indices[0]),
              phoneNumber: _getCellValue(row, indices[1]),
              msanCode: _getCellValue(row, indices[2]),
              frame: _getCellValue(row, indices[3]),
              shelf: _getCellValue(row, indices[4]),
              slot: _getCellValue(row, indices[5]),
              portNumber: _getCellValue(row, indices[6]),
              portType: _getCellValue(row, indices[7]),
              voiceStatus: _getCellValue(row, indices[8]),
              dataStatus: _getCellValue(row, indices[9]),
              operator: _getCellValue(row, indices[10]),
            );
            if (record.phoneNumber.isNotEmpty) {
              await box.add(record);
              count++;
            }
          }
        }
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(HomePage.localeCode == 'en'
                ? 'Loaded $count records'
                : 'تم تحميل $count سجل'),
            backgroundColor: Colors.green,
          ),
        );
        _performSearch();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(HomePage.localeCode == 'en' ? 'Error: $e' : 'خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _search() {
    _performSearch();
  }

  String _calculateCabinetResult(MsaRecord record) {
    if (_cabinetType == null) return '—';
    int? frame = int.tryParse(record.frame);
    if (frame == null) return 'Invalid Frame';
    int row = frame ~/ 16;
    int col = frame % 16;
    int adjustedRow = row >= 64 ? row - 64 : row;
    int portDisplay = (_cabinetType == 'ZTE') ? col + 0 : col;
    final isArabic = HomePage.localeCode == 'ar';
    if (isArabic) {
      return '${adjustedRow + 1} / مشط\n$portDisplay / بورت';
    } else {
      return 'Row: ${adjustedRow + 1}\nPort: $portDisplay';
    }
  }

  Future<void> _editRecord(MsaRecord record) async {
    final formKey = GlobalKey<FormState>();
    final controllers = {
      'Area Code': TextEditingController(text: record.areaCode),
      'Phone Number': TextEditingController(text: record.phoneNumber),
      'MSAN Code': TextEditingController(text: record.msanCode),
      'Frame': TextEditingController(text: record.frame),
      'Shelf': TextEditingController(text: record.shelf),
      'Slot': TextEditingController(text: record.slot),
      'Port number': TextEditingController(text: record.portNumber),
      'Port type': TextEditingController(text: record.portType),
      'Voice Status': TextEditingController(text: record.voiceStatus),
      'Data Status': TextEditingController(text: record.dataStatus),
      'Operator': TextEditingController(text: record.operator),
    };

    final isArabic = HomePage.localeCode == 'ar';
    final fieldNames = [
      'Area Code',
      'Phone Number',
      'MSAN Code',
      'Frame',
      'Shelf',
      'Slot',
      'Port number',
      'Port type',
      'Voice Status',
      'Data Status',
      'Operator',
    ];

    final arabicNames = {
      'Area Code': 'رمز المنطقة',
      'Phone Number': 'رقم الهاتف',
      'MSAN Code': 'رمز MSAN',
      'Frame': 'الإطار',
      'Shelf': 'الرف',
      'Slot': 'الفتحة',
      'Port number': 'رقم المنفذ',
      'Port type': 'نوع المنفذ',
      'Voice Status': 'حالة الصوت',
      'Data Status': 'حالة البيانات',
      'Operator': 'المشغل',
    };

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isArabic ? 'تعديل السجل' : 'Edit Record'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: fieldNames.map((field) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TextFormField(
                    controller: controllers[field],
                    decoration: InputDecoration(
                      labelText: isArabic ? arabicNames[field] : field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                record.areaCode = controllers['Area Code']!.text;
                record.phoneNumber = controllers['Phone Number']!.text;
                record.msanCode = controllers['MSAN Code']!.text;
                record.frame = controllers['Frame']!.text;
                record.shelf = controllers['Shelf']!.text;
                record.slot = controllers['Slot']!.text;
                record.portNumber = controllers['Port number']!.text;
                record.portType = controllers['Port type']!.text;
                record.voiceStatus = controllers['Voice Status']!.text;
                record.dataStatus = controllers['Data Status']!.text;
                record.operator = controllers['Operator']!.text;
                record.save();

                setState(() {
                  _result = record;
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArabic
                        ? 'تم حفظ التغييرات بنجاح'
                        : 'Changes saved successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text(isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    final box = Hive.box<MsaRecord>('msan_records');
    if (box.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['MSAN_Data'];

      List<String> headers = [
        'Area Code',
        'Phone Number',
        'MSAN Code',
        'Frame',
        'Shelf',
        'Slot',
        'Port number',
        'Port type',
        'Voice Status',
        'Data Status',
        'Operator',
      ];
      sheetObject.appendRow(headers);

      for (var record in box.values) {
        sheetObject.appendRow([
          record.areaCode,
          record.phoneNumber,
          record.msanCode,
          record.frame,
          record.shelf,
          record.slot,
          record.portNumber,
          record.portType,
          record.voiceStatus,
          record.dataStatus,
          record.operator,
        ]);
      }

      final directory = await getDownloadsDirectory();
      final filePath =
          '${directory?.path}/MSAN_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to $filePath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = HomePage.localeCode == 'ar';
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isArabic ? 'البحث في MSAN' : 'MSAN Port Finder',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 26,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: IconButton(
              icon: const Icon(Icons.language, color: Colors.white),
              tooltip: isArabic ? 'English' : 'العربية',
              onPressed: _toggleLanguage,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildTopCard(isArabic, screenWidth),
                    const SizedBox(height: 24),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _result == null
                          ? _buildEmptyResultCard(isArabic)
                          : _buildResultCard(_result!, isArabic, screenWidth),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard(bool isArabic, double screenWidth) {
    // Show import/export buttons only on larger screens (> 600)
    final showButtons = screenWidth > 600;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      color: Colors.white.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              // Tablet/desktop layout: row with buttons on the right
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPhoneField(isArabic),
                        const SizedBox(height: 12),
                        _buildCabinetDropdown(isArabic),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  if (showButtons)
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildImportButton(isArabic),
                          const SizedBox(height: 12),
                          _buildExportButton(isArabic),
                        ],
                      ),
                    ),
                ],
              );
            } else {
              // Phone layout: stacked, no buttons
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPhoneField(isArabic),
                  const SizedBox(height: 12),
                  _buildCabinetDropdown(isArabic),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildPhoneField(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'رقم الهاتف' : 'Phone Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          decoration: InputDecoration(
            hintText: isArabic ? 'أدخل رقم الهاتف' : 'Enter phone number',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFF00B4AA), width: 2),
            ),
            suffixIcon: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: _search,
              child: const Icon(Icons.search, color: Color(0xFF00B4AA)),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _search(),
        ),
      ],
    );
  }

  Widget _buildCabinetDropdown(bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'نوع الكابينة' : 'Cabinet Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButton<String>(
            value: _cabinetType,
            isExpanded: true,
            underline: const SizedBox(),
            items: [
              DropdownMenuItem(
                value: 'HUAWEI',
                child: Text(isArabic ? 'هواوي' : 'HUAWEI'),
              ),
              DropdownMenuItem(
                value: 'ZTE',
                child: Text(isArabic ? 'زد تي إي' : 'ZTE'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _cabinetType = value;
                if (_result != null) setState(() {});
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImportButton(bool isArabic) {
    return ElevatedButton(
      onPressed: _importFiles,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00B4AA),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open, size: 20),
          const SizedBox(width: 8),
          Text(isArabic ? 'استيراد ملفات MSAN' : 'Import MSAN Files'),
        ],
      ),
    );
  }

  Widget _buildExportButton(bool isArabic) {
    return OutlinedButton.icon(
      onPressed: _exportToExcel,
      icon: const Icon(Icons.save_alt, size: 20),
      label: Text(isArabic ? 'تصدير إلى Excel' : 'Export to Excel'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF00B4AA),
        side: const BorderSide(color: Color(0xFF00B4AA)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  Widget _buildEmptyResultCard(bool isArabic) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      color: Colors.white.withOpacity(0.9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _phoneController.text.isEmpty
                    ? (isArabic
                    ? 'أدخل رقم الهاتف واضغط على أيقونة البحث'
                    : 'Enter a phone number and tap the search icon')
                    : (isArabic
                    ? 'لم يتم العثور على سجل مطابق'
                    : 'No matching record found'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(MsaRecord record, bool isArabic, double screenWidth) {
    final fields = [
      'Area Code',
      'Phone Number',
      'MSAN Code',
      'Frame',
      'Cabinet Result',
      'Shelf',
      'Slot',
      'Port number',
      'Port type',
      'Voice Status',
      'Data Status',
      'Operator',
    ];

    final arabicNames = {
      'Area Code': 'رمز المنطقة',
      'Phone Number': 'رقم الهاتف',
      'MSAN Code': 'رمز MSAN',
      'Frame': 'الإطار',
      'Cabinet Result': isArabic ? 'نتيجة الكابينة' : 'Cabinet Result',
      'Shelf': 'الرف',
      'Slot': 'الفتحة',
      'Port number': 'رقم المنفذ',
      'Port type': 'نوع المنفذ',
      'Voice Status': 'حالة الصوت',
      'Data Status': 'حالة البيانات',
      'Operator': 'المشغل',
    };

    int crossAxisCount = 1;
    if (screenWidth > 1200) crossAxisCount = 4;
    else if (screenWidth > 800) crossAxisCount = 3;
    else if (screenWidth > 500) crossAxisCount = 2;

    String cabinetResult = _calculateCabinetResult(record);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B4AA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.check_circle, color: Color(0xFF00B4AA)),
                ),
                const SizedBox(width: 12),
                Text(
                  isArabic ? 'تم العثور على سجل' : 'Record Found',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF00B4AA)),
                  onPressed: () => _editRecord(record),
                  tooltip: isArabic ? 'تعديل' : 'Edit',
                ),
              ],
            ),
            const Divider(height: 32),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: fields.map((field) {
                String value;
                if (field == 'Cabinet Result') {
                  value = cabinetResult;
                } else {
                  value = record.toMap()[field] ?? '';
                }
                final label = isArabic ? arabicNames[field]! : field;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00B4AA),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value.isEmpty ? '—' : value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _phoneController.removeListener(_onPhoneNumberChanged);
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  static const String appVersion = '2.2.0';
}
