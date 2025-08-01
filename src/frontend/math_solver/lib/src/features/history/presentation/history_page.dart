import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_solver/route_observer.dart';

import '../controller/history_controller.dart';
import 'history_detail_page.dart';

/// =====================
///  HistoryPage
/// =====================

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      // Safe: HistoryPage is pushed via MaterialPageRoute → a PageRoute.
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called when another route has been popped and we’re visible again.
  @override
  void didPopNext() {
    ref.read(historyControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final asyncHist = ref.watch(historyControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: asyncHist.when(
        loading:
            () => const Center(child: CircularProgressIndicator.adaptive()),
        error:
            (err, _) => Center(
              child: Text('Failed: $err', textAlign: TextAlign.center),
            ),
        data: (items) {
          final solved = items
              .where((e) => e.type == 'enough_info')
              .toList(growable: false);
          final unreadable = items
              .where((e) => e.type == 'not_enough_info')
              .toList(growable: false);

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [Tab(text: 'Solved'), Tab(text: 'Unreadable')],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _GalleryGrid(items: solved),
                      _GalleryGrid(items: unreadable),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// =====================
///  Grid widget
/// =====================

class _GalleryGrid extends ConsumerWidget {
  const _GalleryGrid({required this.items});

  final List<HistoryItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(historyControllerProvider.notifier).refresh(),
      child:
          items.isEmpty
              ? ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 200),
                  Center(child: Text('No items')),
                ],
              )
              : Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  itemCount: items.length,
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    return GestureDetector(
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HistoryDetailPage(item: item),
                            ),
                          ),
                      child: Hero(
                        tag: item.id,
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          placeholder:
                              (c, _) => const ColoredBox(color: Colors.black12),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
