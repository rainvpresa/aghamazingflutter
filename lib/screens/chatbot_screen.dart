import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/userprofile_service.dart';
import '../services/sound_manager.dart'; // 🔊 added
import '../services/faq_service.dart';

// ─────────────────────────────────────────────
//  DOST-STII BRAND COLORS
// ─────────────────────────────────────────────
const kYaleBlue = Color(0xFF004A98);
const kRedPigment = Color(0xFFED262A);
const kEerieBlack = Color(0xFF1E1E1E);
const kWhite = Color(0xFFFFFFFF);
const kLightBlue = Color(0xFFE8F0F9);
const kGrey = Color(0xFFF4F6FA);

// ─────────────────────────────────────────────
//  RESPONSIVE LAYOUT HELPER
// ─────────────────────────────────────────────
class _Layout {
  final double screenWidth;
  final double screenHeight;

  const _Layout({required this.screenWidth, required this.screenHeight});

  factory _Layout.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return _Layout(screenWidth: size.width, screenHeight: size.height);
  }

  double r(double value) => value * (screenWidth / 360);

  double sp(double value) {
    final scale = (screenWidth / 360).clamp(0.8, 1.4);
    return value * scale;
  }

  int get gridColumns => screenWidth > screenHeight ? 5 : 3;
  double get hPad => r(16).clamp(12.0, 32.0);
  double get bubbleMaxWidth => screenWidth * 0.72;
}

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────
class FaqCategory {
  final String id;
  final String label;
  final IconData icon;
  final List<FaqItem> items;

  const FaqCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.items,
  });
}

class FaqItem {
  final String question;
  final String answer;
  final List<String>? actionButtons;

  const FaqItem({
    required this.question,
    required this.answer,
    this.actionButtons,
  });
}

// ─────────────────────────────────────────────
//  HARDCODED FALLBACK FAQ CONTENT
// ─────────────────────────────────────────────
final List<FaqCategory> kFaqCategories = [
  FaqCategory(
    id: 'about',
    label: 'About STII',
    icon: Icons.info_outline_rounded,
    items: [
      FaqItem(
        question: 'What is DOST-STII?',
        answer:
        'The Science and Technology Information Institute (STII) is an agency under the Department of Science and Technology (DOST) of the Philippines. It serves as the country\'s primary S&T information clearing house, disseminating science and technology information to the public.',
        actionButtons: ['Visit Website'],
      ),
      FaqItem(
        question: 'What is STII\'s mandate?',
        answer:
        'STII\'s mandate is to serve as the S&T information clearing house of the Philippines. It collects, processes, and disseminates S&T information, and promotes awareness of the country\'s S&T activities, achievements, and resources.',
        actionButtons: ['Visit Website'],
      ),
      FaqItem(
        question: 'Where is STII located?',
        answer:
        'DOST-STII is located at the DOST Compound, General Santos Avenue, Bicutan, Taguig City, Metro Manila, Philippines.',
        actionButtons: ['Get Directions'],
      ),
    ],
  ),
  FaqCategory(
    id: 'services',
    label: 'Services',
    icon: Icons.design_services_rounded,
    items: [
      FaqItem(
        question: 'What services does STII offer?',
        answer:
        'STII offers a wide range of services including: S&T Information Services, Library and Reference Services, Science Journalism Training, Digital Publishing, STARBOOKS (Science and Technology Academic and Research-Based Openly Operated KioskS), and the InfoSerbilis mobile library.',
      ),
      FaqItem(
        question: 'What is STARBOOKS?',
        answer:
        'STARBOOKS (Science and Technology Academic and Research-Based Openly Operated KioskS) is a digital library developed by DOST-STII. It provides access to science and technology learning resources for schools and communities in the Philippines, especially in areas with limited internet connectivity.',
      ),
      FaqItem(
        question: 'What is InfoSerbilis?',
        answer:
        'InfoSerbilis is DOST-STII\'s mobile library and information service that brings S&T information directly to communities. It operates as a mobile unit that visits schools, barangays, and public events to deliver science and technology resources.',
      ),
    ],
  ),
  FaqCategory(
    id: 'publications',
    label: 'Publications',
    icon: Icons.menu_book_rounded,
    items: [
      FaqItem(
        question: 'What publications does STII produce?',
        answer:
        'STII produces several S&T publications including: S&T Post (newsletter), Philippine Journal of Science (peer-reviewed journal), DOST Digest, Balitang Rapidost, Philippine Men & Women of Science, SPHERES, and Philippine S&T Abstracts.',
      ),
      FaqItem(
        question: 'How can I access the Philippine Journal of Science?',
        answer:
        'The Philippine Journal of Science is available online at philjournalsci.dost.gov.ph. It is a peer-reviewed, open-access journal that publishes original research in natural, applied, and social sciences.',
      ),
      FaqItem(
        question: 'Can I submit articles to STII publications?',
        answer:
        'Yes! STII welcomes submissions for its various publications. For the Philippine Journal of Science, researchers may submit manuscripts through the journal\'s official website. For other publications like the S&T Post, you may contact STII directly.',
      ),
    ],
  ),
  FaqCategory(
    id: 'programs',
    label: 'Programs',
    icon: Icons.science_rounded,
    items: [
      FaqItem(
        question: 'What is the Science Journo Ako program?',
        answer:
        'Science Journo Ako is a DOST-STII training program that capacitates media practitioners, students, and communicators in science journalism. It aims to improve the quality of science reporting in the Philippines.',
      ),
      FaqItem(
        question: 'Does STII have programs for students?',
        answer:
        'Yes! STII has programs for students including STARBOOKS access in schools, Science Journo Ako for aspiring science journalists, and various science communication workshops and training programs.',
      ),
      FaqItem(
        question: 'What is SCALEUP?',
        answer:
        'SCALEUP (Science Communication and Literacy Enhancement Under the Philippine Science) is an STII initiative that includes programs such as Science Journo Ako, Make Your Library Alive (MYLA), Lights Camera Rolling, and Navigating STARBOOKS Through User-Centric Learning.',
      ),
    ],
  ),
  FaqCategory(
    id: 'contact',
    label: 'Contact',
    icon: Icons.contact_support_rounded,
    items: [
      FaqItem(
        question: 'How can I contact STII?',
        answer:
        'You can reach DOST-STII through the following:\n• Visit: DOST Compound, General Santos Avenue, Bicutan, Taguig City\n• Website: www.stii.dost.gov.ph\n• Use the Contact Us page on the STII website for inquiries.',
        actionButtons: ['Contact Form'],
      ),
      FaqItem(
        question: 'What are STII\'s office hours?',
        answer:
        'DOST-STII operates on regular government office hours: Monday to Friday, 8:00 AM to 5:00 PM, except on official holidays. For online inquiries, you may submit through the website at any time.',
      ),
    ],
  ),
];

// ─────────────────────────────────────────────
//  RICH TEXT HELPER
// ─────────────────────────────────────────────
List<TextSpan> _parseBoldText(String text, TextStyle base) {
  final spans = <TextSpan>[];
  final regex = RegExp(r'\*\*(.+?)\*\*');
  int cursor = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start), style: base));
    }
    spans.add(TextSpan(
      text: match.group(1),
      style: base.copyWith(fontWeight: FontWeight.w700),
    ));
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: base));
  }
  return spans;
}

class _RichText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  const _RichText(this.text, {required this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(children: _parseBoldText(text, style)),
    );
  }
}

// ─────────────────────────────────────────────
//  CHAT MESSAGE MODEL
// ─────────────────────────────────────────────
enum MessageType { user, bot, categoryGrid, answerCard }

class ChatMessage {
  final String? text;
  final MessageType type;
  final FaqCategory? category;
  final FaqItem? faqItem;

  ChatMessage({
    this.text,
    required this.type,
    this.category,
    this.faqItem,
  });
}

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  List<FaqCategory> _faqCategories = [];
  bool _isLoadingFaq = true;

  static const String _mapsUrl =
      'https://www.google.com/maps/search/?api=1&query=DOST-STII+Bicutan+Taguig';
  static const String _stiiWebsiteUrl = 'https://www.stii.dost.gov.ph';

  @override
  void initState() {
    super.initState();
    _initFaq();
  }

  Future<void> _initFaq() async {
    final categories = await FaqService.instance.getCategories();
    if (!mounted) return;
    setState(() {
      _faqCategories = categories;
      _isLoadingFaq = false;
    });
    _addWelcomeMessages();
  }

  void _addWelcomeMessages() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _addBotMessage(
          "Magandang araw! 👋 I'm Smarty, your DOST-STII virtual assistant.");
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      _addBotMessage(
          "I can help you with information about our services, publications, programs, and more. What would you like to know today?");
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      setState(() {
        _messages.add(ChatMessage(type: MessageType.categoryGrid));
      });
      _scrollToBottom();
    });
  }

  void _addBotMessage(String text, {bool animate = true}) {
    if (animate) setState(() => _isTyping = true);
    Future.delayed(Duration(milliseconds: animate ? 600 : 0), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: text, type: MessageType.bot));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onCategoryTapped(FaqCategory category) {
    SoundManager.instance.playClick(); // 🔊
    setState(() {
      _messages.add(ChatMessage(text: category.label, type: MessageType.user));
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 400), () {
      setState(() => _isTyping = true);
    });

    if (category.items.length == 1) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _onQuestionTapped(category.items.first, skipUserBubble: true);
      });
    } else {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(
            text:
            "Here are some common questions about **${category.label}**. Tap one to get an answer:",
            type: MessageType.bot,
          ));
          _messages.add(ChatMessage(
            type: MessageType.answerCard,
            category: category,
          ));
        });
        _scrollToBottom();
      });
    }
  }

  void _onQuestionTapped(FaqItem item, {bool skipUserBubble = false}) {
    SoundManager.instance.playClick(); // 🔊
    if (!skipUserBubble) {
      setState(() {
        _messages.add(ChatMessage(text: item.question, type: MessageType.user));
      });
      _scrollToBottom();
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      setState(() => _isTyping = true);
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(
            ChatMessage(text: item.answer, type: MessageType.bot, faqItem: item));
      });

      final bool hasButtons =
          item.actionButtons != null && item.actionButtons!.isNotEmpty;

      if (hasButtons) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(() {
            _messages.add(ChatMessage(
              type: MessageType.categoryGrid,
              faqItem: item,
            ));
          });
          _scrollToBottom();
        });
      } else {
        _showFollowUp();
      }
    });
  }

  void _showFollowUp() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _addBotMessage("Is there anything else I can help you with?",
          animate: false);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() {
          _messages.add(ChatMessage(type: MessageType.categoryGrid));
        });
        _scrollToBottom();
      });
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.')),
      );
    }
  }

  void _showFeedbackModal() async {
    SoundManager.instance.playClick(); // 🔊
    final profile = await UserProfileService().getUserProfile();
    final username = profile?['displayName'] ?? 'Anonymous';
    final userId = profile?['uid'] ?? '';
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeedbackModal(username: username, userId: userId),
    );
  }

  void _onActionButtonTapped(String label) {
    SoundManager.instance.playClick(); // 🔊
    switch (label) {
      case 'Visit Website':
        _launchUrl(_stiiWebsiteUrl);
        break;
      case 'Get Directions':
        _launchUrl(_mapsUrl);
        break;
      case 'Contact Form':
        _showFeedbackModal(); // 🔊 already has its own click inside
        break;
      case 'Back to Menu':
        setState(() {
          _messages
              .add(ChatMessage(text: 'Back to Menu', type: MessageType.user));
        });
        _addBotMessage("Sure! Here are our main topics. How can I help you?",
            animate: false);
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(() {
            _messages.add(ChatMessage(type: MessageType.categoryGrid));
          });
          _scrollToBottom();
        });
        break;
      default:
        setState(() {
          _messages.add(ChatMessage(text: label, type: MessageType.user));
        });
        _addBotMessage(
            "For \"$label\", please visit our website at www.stii.dost.gov.ph or contact us directly.");
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final layout = _Layout.of(context);

    return Scaffold(
      backgroundColor: kGrey,
      appBar: _buildAppBar(layout),
      body: Column(
        children: [
          _buildAdvisoryBanner(layout),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                  horizontal: layout.hPad, vertical: layout.r(12)),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _buildTypingIndicator(layout);
                }
                return _buildMessageWidget(_messages[index], layout);
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(_Layout layout) {
    final avatarSize = layout.r(38);
    final iconSize = layout.r(22);

    return AppBar(
      backgroundColor: kYaleBlue,
      foregroundColor: kWhite,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: layout.r(20)),
        onPressed: () {
          SoundManager.instance.playClick(); // 🔊
          Navigator.of(context).maybePop();
        },
      ),
      title: Row(
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: kWhite,
              shape: BoxShape.circle,
              border: Border.all(color: kRedPigment, width: 2),
            ),
            child: ClipOval(
              child: Padding(
                padding: EdgeInsets.all(layout.r(6)),
                child: Icon(Icons.support_agent_rounded,
                    color: kYaleBlue, size: iconSize),
              ),
            ),
          ),
          SizedBox(width: layout.r(10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smarty Bird',
                style: TextStyle(
                    fontSize: layout.sp(15),
                    fontWeight: FontWeight.w700,
                    color: kWhite),
              ),
              Row(
                children: [
                  Container(
                    width: layout.r(7),
                    height: layout.r(7),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: layout.r(4)),
                  Text('Online',
                      style: TextStyle(
                          fontSize: layout.sp(11),
                          color: const Color(0xFFBFD9F5))),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: const [],
    );
  }

  Widget _buildAdvisoryBanner(_Layout layout) {
    return Container(
      color: const Color(0xFFFFF8E1),
      padding: EdgeInsets.symmetric(
          horizontal: layout.hPad, vertical: layout.r(8)),
      child: Row(
        children: [
          Icon(Icons.campaign_rounded,
              size: layout.r(16), color: const Color(0xFFF59E0B)),
          SizedBox(width: layout.r(8)),
          Expanded(
            child: Text(
              'Visit stii.dost.gov.ph for the latest S&T news and updates.',
              style: TextStyle(
                  fontSize: layout.sp(12),
                  color: const Color(0xFF92400E),
                  fontWeight: FontWeight.w500),
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: layout.r(16), color: const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildMessageWidget(ChatMessage msg, _Layout layout) {
    switch (msg.type) {
      case MessageType.user:
        return _buildUserBubble(msg.text!, layout);
      case MessageType.bot:
        return _buildBotBubble(msg.text!, layout);
      case MessageType.categoryGrid:
        if (msg.faqItem != null) return _buildActionButtons(msg.faqItem!, layout);
        return _buildCategoryGrid(layout);
      case MessageType.answerCard:
        return _buildQuestionList(msg.category!, layout);
    }
  }

  Widget _buildUserBubble(String text, _Layout layout) {
    return Padding(
      padding: EdgeInsets.only(bottom: layout.r(12), left: layout.r(60)),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.bubbleMaxWidth),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: layout.r(16), vertical: layout.r(12)),
            decoration: BoxDecoration(
              color: kYaleBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                    color: kYaleBlue.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                  color: kWhite, fontSize: layout.sp(14), height: 1.4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotBubble(String text, _Layout layout) {
    return Padding(
      padding: EdgeInsets.only(bottom: layout.r(12), right: layout.r(60)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: layout.r(32),
            height: layout.r(32),
            margin: EdgeInsets.only(right: layout.r(8), top: layout.r(2)),
            decoration: BoxDecoration(
              color: kYaleBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: kYaleBlue.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Icon(Icons.support_agent_rounded,
                color: kWhite, size: layout.r(18)),
          ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.bubbleMaxWidth),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: layout.r(16), vertical: layout.r(12)),
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: _RichText(
                  text,
                  style: TextStyle(
                      color: kEerieBlack,
                      fontSize: layout.sp(14),
                      height: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(_Layout layout) {
    return Padding(
      padding: EdgeInsets.only(bottom: layout.r(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: layout.r(40), bottom: layout.r(8)),
            child: Text(
              'Browse by category:',
              style: TextStyle(
                  fontSize: layout.sp(12),
                  color: Colors.grey,
                  fontWeight: FontWeight.w500),
            ),
          ),
          _isLoadingFaq
              ? const Center(child: CircularProgressIndicator())
              : GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: layout.gridColumns,
            mainAxisSpacing: layout.r(10),
            crossAxisSpacing: layout.r(10),
            childAspectRatio: 1.1,
            children: _faqCategories
                .map((cat) => _buildCategoryCard(cat, layout))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(FaqCategory cat, _Layout layout) {
    return GestureDetector(
      onTap: () => _onCategoryTapped(cat), // 🔊 sound called inside
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(layout.r(14)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: layout.r(40),
              height: layout.r(40),
              decoration: const BoxDecoration(
                color: kLightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(cat.icon, color: kYaleBlue, size: layout.r(20)),
            ),
            SizedBox(height: layout.r(6)),
            Text(
              cat.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: layout.sp(11),
                  fontWeight: FontWeight.w600,
                  color: kEerieBlack),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionList(FaqCategory category, _Layout layout) {
    return Padding(
      padding: EdgeInsets.only(bottom: layout.r(16), left: layout.r(40)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: category.items
            .map((item) => _buildQuestionChip(item, layout))
            .toList(),
      ),
    );
  }

  Widget _buildQuestionChip(FaqItem item, _Layout layout) {
    return GestureDetector(
      onTap: () => _onQuestionTapped(item), // 🔊 sound called inside
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: layout.r(8), right: layout.r(20)),
        padding: EdgeInsets.symmetric(
            horizontal: layout.r(16), vertical: layout.r(12)),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(layout.r(12)),
          border: Border.all(color: kYaleBlue.withOpacity(0.25), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.help_outline_rounded,
                size: layout.r(16), color: kYaleBlue),
            SizedBox(width: layout.r(10)),
            Expanded(
              child: Text(
                item.question,
                style: TextStyle(
                    fontSize: layout.sp(13),
                    color: kYaleBlue,
                    fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: layout.r(16), color: kYaleBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(FaqItem item, _Layout layout) {
    return Padding(
      padding: EdgeInsets.only(bottom: layout.r(16), left: layout.r(40)),
      child: Wrap(
        spacing: layout.r(8),
        runSpacing: layout.r(8),
        children: [
          ...item.actionButtons!
              .map((label) => _buildActionButton(label, layout)),
          _buildActionButton('Back to Menu', layout,
              isSecondary: true, icon: Icons.home_rounded),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, _Layout layout,
      {bool isSecondary = false, IconData? icon}) {
    final bool isLink = label == 'Visit Website';

    return GestureDetector(
      onTap: () => _onActionButtonTapped(label), // 🔊 sound called inside
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: layout.r(14), vertical: layout.r(9)),
        decoration: BoxDecoration(
          color: isSecondary
              ? kWhite
              : isLink
              ? const Color(0xFFE8F0F9)
              : kRedPigment,
          borderRadius: BorderRadius.circular(layout.r(20)),
          border: isSecondary
              ? Border.all(color: kRedPigment, width: 1.5)
              : isLink
              ? Border.all(color: kYaleBlue.withOpacity(0.4), width: 1)
              : null,
          boxShadow: [
            BoxShadow(
                color: (isLink ? kYaleBlue : kRedPigment).withOpacity(0.18),
                blurRadius: 6,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ??
                  (isLink
                      ? Icons.open_in_new_rounded
                      : label == 'Get Directions'
                      ? Icons.directions_rounded
                      : label == 'Contact Form'
                      ? Icons.feedback_outlined
                      : Icons.arrow_forward_rounded),
              size: layout.r(14),
              color: isSecondary
                  ? kRedPigment
                  : isLink
                  ? kYaleBlue
                  : kWhite,
            ),
            SizedBox(width: layout.r(5)),
            Text(
              label,
              style: TextStyle(
                fontSize: layout.sp(12),
                fontWeight: FontWeight.w600,
                color: isSecondary
                    ? kRedPigment
                    : isLink
                    ? kYaleBlue
                    : kWhite,
                decoration:
                isLink ? TextDecoration.underline : TextDecoration.none,
                decorationColor: kYaleBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(_Layout layout) {
    return Padding(
      padding: EdgeInsets.only(bottom: layout.r(12), right: layout.r(60)),
      child: Row(
        children: [
          Container(
            width: layout.r(32),
            height: layout.r(32),
            margin: EdgeInsets.only(right: layout.r(8)),
            decoration: const BoxDecoration(
                color: kYaleBlue, shape: BoxShape.circle),
            child: Icon(Icons.support_agent_rounded,
                color: kWhite, size: layout.r(18)),
          ),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: layout.r(16), vertical: layout.r(12)),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(layout.r(18)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────
//  FEEDBACK MODAL
// ─────────────────────────────────────────────
class _FeedbackModal extends StatefulWidget {
  final String username;
  final String userId;

  const _FeedbackModal({
    required this.username,
    required this.userId,
  });

  @override
  State<_FeedbackModal> createState() => _FeedbackModalState();
}

class _FeedbackModalState extends State<_FeedbackModal> {
  final TextEditingController _feedbackController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;
  bool _submitted = false;

  Future<void> _submit() async {
    SoundManager.instance.playClick(); // 🔊
    final text = _feedbackController.text.trim();
    if (_rating == 0 && text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please provide a rating or feedback before submitting.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('chatbot_feedback').add({
        'userId': widget.userId,
        'username': widget.username,
        'feedback': text,
        'rating': _rating,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = _Layout.of(context);
    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            layout.r(24), layout.r(16), layout.r(24), layout.r(32)),
        child: _submitted ? _buildSuccess(layout) : _buildForm(layout),
      ),
    );
  }

  Widget _buildSuccess(_Layout layout) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: layout.r(16)),
        Container(
          width: layout.r(64),
          height: layout.r(64),
          decoration: const BoxDecoration(
            color: Color(0xFFE6F4EA),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded,
              color: const Color(0xFF34A853), size: layout.r(36)),
        ),
        SizedBox(height: layout.r(16)),
        Text(
          'Thank you for your feedback!',
          style: TextStyle(
              fontSize: layout.sp(17),
              fontWeight: FontWeight.w700,
              color: kEerieBlack),
        ),
        SizedBox(height: layout.r(8)),
        Text(
          'Your response has been recorded and will help us improve our services.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: layout.sp(13), color: Colors.grey),
        ),
        SizedBox(height: layout.r(24)),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kYaleBlue,
              foregroundColor: kWhite,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(layout.r(14))),
              padding: EdgeInsets.symmetric(vertical: layout.r(14)),
            ),
            onPressed: () {
              SoundManager.instance.playClick(); // 🔊
              Navigator.of(context).pop();
            },
            child: Text('Close',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: layout.sp(14))),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(_Layout layout) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: layout.r(40),
            height: layout.r(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        SizedBox(height: layout.r(20)),
        Row(
          children: [
            Container(
              width: layout.r(40),
              height: layout.r(40),
              decoration: const BoxDecoration(
                color: kLightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.feedback_outlined,
                  color: kYaleBlue, size: layout.r(20)),
            ),
            SizedBox(width: layout.r(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share Your Feedback',
                    style: TextStyle(
                        fontSize: layout.sp(16),
                        fontWeight: FontWeight.w700,
                        color: kEerieBlack),
                  ),
                  Text(
                    'Help us improve DOST-STII\'s chatbot',
                    style:
                    TextStyle(fontSize: layout.sp(12), color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: layout.r(24)),
        Text(
          'How would you rate your experience?',
          style: TextStyle(
              fontSize: layout.sp(13),
              fontWeight: FontWeight.w600,
              color: kEerieBlack),
        ),
        SizedBox(height: layout.r(10)),
        Row(
          children: List.generate(5, (i) {
            final starIndex = i + 1;
            return GestureDetector(
              onTap: () {
                SoundManager.instance.playClick(); // 🔊
                setState(() => _rating = starIndex);
              },
              child: Padding(
                padding: EdgeInsets.only(right: layout.r(6)),
                child: Icon(
                  starIndex <= _rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: layout.r(36),
                  color: starIndex <= _rating
                      ? const Color(0xFFF59E0B)
                      : Colors.grey.shade300,
                ),
              ),
            );
          }),
        ),
        if (_rating > 0)
          Padding(
            padding: EdgeInsets.only(top: layout.r(6)),
            child: Text(
              ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent!'][_rating],
              style: TextStyle(
                  fontSize: layout.sp(12),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF59E0B)),
            ),
          ),
        SizedBox(height: layout.r(20)),
        Text(
          'Additional comments (optional)',
          style: TextStyle(
              fontSize: layout.sp(13),
              fontWeight: FontWeight.w600,
              color: kEerieBlack),
        ),
        SizedBox(height: layout.r(8)),
        TextField(
          controller: _feedbackController,
          maxLines: 4,
          maxLength: 500,
          style: TextStyle(fontSize: layout.sp(14), color: kEerieBlack),
          decoration: InputDecoration(
            hintText: 'Tell us about your experience...',
            hintStyle: TextStyle(
                color: Colors.grey.shade400, fontSize: layout.sp(14)),
            filled: true,
            fillColor: kGrey,
            contentPadding: EdgeInsets.all(layout.r(14)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(layout.r(14)),
              borderSide: BorderSide.none,
            ),
            counterStyle: TextStyle(
                fontSize: layout.sp(11), color: Colors.grey.shade400),
          ),
        ),
        SizedBox(height: layout.r(8)),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kYaleBlue,
              foregroundColor: kWhite,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(layout.r(14))),
              padding: EdgeInsets.symmetric(vertical: layout.r(14)),
            ),
            onPressed: _isSubmitting ? null : _submit, // 🔊 sound called inside _submit
            child: _isSubmitting
                ? SizedBox(
              height: layout.r(18),
              width: layout.r(18),
              child: const CircularProgressIndicator(
                  color: kWhite, strokeWidth: 2),
            )
                : Text('Submit Feedback',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: layout.sp(14))),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────
//  ANIMATED TYPING DOTS
// ─────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final double offset =
            ((_controller.value * 3) - i).clamp(0.0, 1.0);
            final double bounce =
            offset < 0.5 ? offset * 2 : (1 - offset) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7 + (bounce * 5),
              decoration: BoxDecoration(
                color: kYaleBlue.withOpacity(0.5 + bounce * 0.5),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}