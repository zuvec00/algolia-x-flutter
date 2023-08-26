import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter x Algolia',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: Colors.blueAccent.shade700),
        textTheme: TextTheme(
            bodyMedium:
                GoogleFonts.quicksand(fontSize: 16, color: Colors.grey[900])),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class HitsPage {
  final List<Product> items;
  final int pageKey;
  final int? nextPageKey;

  const HitsPage(this.items, this.pageKey, this.nextPageKey);

  factory HitsPage.fromResponse(SearchResponse response) {
    final items = response.hits.map(Product.fromJson).toList();
    final isLastPage = response.page >= response.nbPages;
    final nextPageKey = isLastPage ? null : response.page;
    return HitsPage(items, response.page, nextPageKey);
  }
}

class Product {
  final String name;
  final String image;

  Product(this.name, this.image);

  static Product fromJson(Map<String, dynamic> json) {
    return Product(json['name'], json['image_urls'][0]);
  }
}

class SearchMetadata {
  final int nbHits;

  const SearchMetadata(this.nbHits);

  factory SearchMetadata.fromResponse(SearchResponse response) =>
      SearchMetadata(response.nbHits);
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final PagingController<int, Product> _pagingController =
      PagingController(firstPageKey: 0);
  //The HitsSearcher componenent is responsible for handling search request and retrieving search results
  final _productsSearcher = HitsSearcher(
      apiKey: '927c3fe76d4b52c5a2912973f35a3077',
      applicationID: 'latency',
      indexName: 'STAGING_native_ecom_demo_products');

  final _searchTextController = TextEditingController();

  Stream<SearchMetadata> get _searchMetadata =>
      _productsSearcher.responses.map(SearchMetadata.fromResponse);

  Stream<HitsPage> get _searchPage =>
      _productsSearcher.responses.map(HitsPage.fromResponse);

  final _filterState = FilterState();

  late final _facetList = FacetList(
      searcher: _productsSearcher,
      filterState: _filterState,
      attribute: 'brand');

  final GlobalKey<ScaffoldState> _mainScaffoldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _searchTextController.addListener(
        () => _productsSearcher.applyState((state) => state.copyWith(
              query: _searchTextController.text,
              page: 0,
            )));

    _searchPage.listen((page) {
      if (page.pageKey == 0) {
        _pagingController.refresh();
      }
      _pagingController.appendPage(page.items, page.nextPageKey);
    }).onError((error) => _pagingController.error = error);
    _pagingController.addPageRequestListener((pageKey) =>
        _productsSearcher.applyState((state) => state.copyWith(page: pageKey)));

    _productsSearcher.connectFilterState(_filterState);
    _filterState.filters.listen((event) {
      return _pagingController.refresh();
    });
  }

  Widget _hits(BuildContext context) => PagedListView<int, Product>(
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<Product>(
            noItemsFoundIndicatorBuilder: (_) => const Center(
                  child: Text('No results found'),
                ),
            itemBuilder: (_, item, __) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 7.5),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 100,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Image.network(item.image),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: Text(item.name))
                    ],
                  ),
                )),
      );

  Widget _filters(BuildContext context) => Scaffold(
      backgroundColor: Colors.blueAccent.shade400,
      appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.blueAccent.shade400,
          centerTitle: true,
          title: Text('Filters',
              style: GoogleFonts.quicksand(color: Colors.grey[100]))),
      body: StreamBuilder<List<SelectableItem<Facet>>>(
          stream: _facetList.facets,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }
            final selectableFacets = snapshot.data!;
            return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: selectableFacets.length,
                itemBuilder: (_, index) {
                  final selectableFacet = selectableFacets[index];
                  return CheckboxListTile(
                      activeColor: Colors.white,
                      checkColor: Colors.blueAccent.shade700,
                      value: selectableFacet.isSelected,
                      title: Text(
                          '${selectableFacet.item.value} (${selectableFacet.item.count})',
                          style:
                              GoogleFonts.quicksand(color: Colors.grey[100])),
                      onChanged: (_) {
                        _facetList.toggle(selectableFacet.item.value);
                      });
                });
          }));

  Widget build(BuildContext context) {
    return Scaffold(
      key: _mainScaffoldKey,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        centerTitle: true,
        elevation: 0,
        title: Text('Algolia & Flutter', style: GoogleFonts.quicksand()),
        actions: [
          IconButton(
            color: Colors.blueAccent.shade700,
            onPressed: () => _mainScaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(
              Icons.filter_list_sharp,
            ),
          )
        ],
      ),
      endDrawer: Drawer(
        child: _filters(context),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CupertinoSearchTextField(
              controller: _searchTextController,
              onSuffixTap: () {
                _searchTextController.clear();
              },
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              backgroundColor: Colors.grey[200],
              borderRadius: BorderRadius.circular(15),
              prefixIcon: Icon(FluentSystemIcons.ic_fluent_search_regular,
                  size: 26, color: Colors.grey[900]),
              suffixIcon: const Icon(
                  FluentSystemIcons.ic_fluent_dismiss_circle_regular),
              placeholder: 'Search products...',
              placeholderStyle:
                  GoogleFonts.quicksand(fontSize: 14, color: Colors.grey[600]),
            ),
            StreamBuilder<SearchMetadata>(
                stream: _searchMetadata,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('${snapshot.data!.nbHits} results',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent.shade700)),
                  );
                }),
            Expanded(child: _hits(context))
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    _productsSearcher.dispose();
    _pagingController.dispose();
    _filterState.dispose();
    _facetList.dispose();
    super.dispose();
  }
}
