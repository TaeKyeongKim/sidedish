//
//  ProductCollectionViewModel.swift
//  SideDishApp
//
//  Created by Kai Kim on 2022/04/20.
//

import Foundation

// This is going to represent single viewModel that drives productCollectionView

struct CategorySectionViewModel {
    var type: CategoryType
    var productVMs: [ProductCellViewModel]
}

struct MainCollectionViewModel {

    private let networkManager = NetworkManager()
    private var imageCache = NSCache<NSURL, NSData>()
    var categoryVMs: [CategoryType: Observable<CategorySectionViewModel>]
    var headerVMs: [CategoryType: Observable<HeaderInfoViewModel>]
    let semaphore = DispatchSemaphore(value: 0)

    init () {
        let placeHolders = (0..<5).map({ _ in
            ProductCellViewModel.makePlaceHolder()
        })
        let placeHolderCategory =  CategorySectionViewModel(type: .main, productVMs: placeHolders)

        categoryVMs = [.main: Observable<CategorySectionViewModel>(placeHolderCategory),
                       .side: Observable<CategorySectionViewModel>(),
                       .soup: Observable<CategorySectionViewModel>()]

        headerVMs = [.main: Observable<HeaderInfoViewModel>(HeaderInfoViewModel()),
                     .side: Observable<HeaderInfoViewModel>(HeaderInfoViewModel()),
                     .soup: Observable<HeaderInfoViewModel>(HeaderInfoViewModel())]

    }

    func countProduct(section: Int) -> Int {
        let targetType = CategoryType.allCases[section]
        guard let productVMs = categoryVMs[targetType]?.value?.productVMs else {return 0}
        return productVMs.count
    }

    func countSection() -> Int {
        self.categoryVMs.count
    }

    subscript(_ indexPath: IndexPath) -> ProductCellViewModel? {
        let targetType = CategoryType.allCases[indexPath.section]
        guard let productVMs = categoryVMs[targetType]?.value?.productVMs else {return nil}
        return productVMs[indexPath.item]
    }

    func fetchAllCategories() {
        CategoryType.allCases.forEach({
            fetchCategories(of: $0)
        })
    }

    private func fetchCategories(of type: CategoryType) {

        guard let categoryRequest = CategoryRequest(from: type) else {
            return
        }

        categoryRequest.execute { categoryResponse in
            guard let productCellVMs = categoryResponse?.body.compactMap({ productSummary in
                ProductCellViewModel(product: productSummary)
            }) else { return }

            let categoryVM = CategorySectionViewModel(type: type, productVMs: productCellVMs)

            categoryVMs[type]?.value = categoryVM
            semaphore.signal()
        }
    }

    func fetchImage(from url: URL, then completion: @escaping (NSData?) -> Void) {
        if let image = imageCache.object(forKey: url as NSURL) {
            return completion(image)
        }

        guard let imageRequest = ImageRequest(url: url) else {
            return
        }

        imageRequest.execute { data in
            guard let data = data as? NSData else {
                return completion(nil)
            }
            imageCache.setObject(data, forKey: url as NSURL)
            completion(data)
        }
    }

    func updateHeaderStatus(_ status: Bool, at type: CategoryType) {
        let targetVM = headerVMs[type]
        targetVM?.value?.isHidden = status
    }
}
