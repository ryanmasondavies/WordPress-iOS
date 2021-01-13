import UIKit

@objc
class MySitesCoordinator: NSObject {
    static let splitViewControllerRestorationID = "splitViewControllerRestorationID"
    static let navigationControllerRestorationID = "navigationControllerRestorationID"

    let meScenePresenter: ScenePresenter

    // MARK: - VCs

    /// The view controller that should be presented by the tab bar controller.
    ///
    @objc
    var rootViewController: UIViewController {
        return splitViewController
    }

    @objc
    private(set) lazy var blogListViewController: BlogListViewController = {
        BlogListViewController(meScenePresenter: self.meScenePresenter)
    }()

    private lazy var splitViewController: WPSplitViewController = {
        let splitViewController = WPSplitViewController()

        splitViewController.restorationIdentifier = MySitesCoordinator.splitViewControllerRestorationID
        splitViewController.presentsWithGesture = false
        splitViewController.setInitialPrimaryViewController(navigationController)
        splitViewController.wpPrimaryColumnWidth = .narrow
        splitViewController.dimsDetailViewControllerAutomatically = true
        splitViewController.tabBarItem = navigationController.tabBarItem

        return splitViewController
    }()

    private lazy var mySiteViewController = {
        MySiteViewController(meScenePresenter: self.meScenePresenter)
    }()

    private lazy var navigationController: UINavigationController = {
        let navigationController = UINavigationController(rootViewController: rootContentViewController())

        if Feature.enabled(.newNavBarAppearance) {
            navigationController.navigationBar.prefersLargeTitles = true
        }

        navigationController.restorationIdentifier = MySitesCoordinator.navigationControllerRestorationID
        navigationController.navigationBar.isTranslucent = false

        let tabBarImage = UIImage(named: "icon-tab-mysites")
        navigationController.tabBarItem.image = tabBarImage
        navigationController.tabBarItem.selectedImage = tabBarImage
        navigationController.tabBarItem.accessibilityLabel = NSLocalizedString("My Site", comment: "The accessibility value of the my site tab.")
        navigationController.tabBarItem.accessibilityIdentifier = "mySitesTabButton"
        navigationController.tabBarItem.title = NSLocalizedString("My Site", comment: "The accessibility value of the my site tab.")
        navigationController.navigationItem.largeTitleDisplayMode = .always
        return navigationController
    }()

    // MARK: - Callbacks

    let becomeActiveTab: () -> Void

    // MARK: - Initializers

    @objc
    init(
        meScenePresenter: ScenePresenter,
        onBecomeActiveTab becomeActiveTab: @escaping () -> Void) {

        self.meScenePresenter = meScenePresenter
        self.becomeActiveTab = becomeActiveTab

        super.init()
    }

    // MARK: - Root View Controller

    private func rootContentViewController() -> UIViewController {
        if Feature.enabled(.newNavBarAppearance) {
            return mySiteViewController
        } else {
            return blogListViewController
        }
    }

    func showRootViewController() {
        becomeActiveTab()

        navigationController.popToRootViewController(animated: false)
    }

    // MARK: - Sites List

    func showSitesList() {
        showRootViewController()

        if Feature.enabled(.newNavBarAppearance) {
            blogListViewController.modalPresentationStyle = .pageSheet
            mySiteViewController.present(blogListViewController, animated: false, completion: nil)
        }
    }

    // MARK: - Blog Details

    @objc
    func showBlogDetails(for blog: Blog) {
        showRootViewController()

        if Feature.enabled(.newNavBarAppearance) {
            mySiteViewController.blog = blog
        } else {
            blogListViewController.setSelectedBlog(blog, animated: false)
        }
    }

    func showBlogDetails(for blog: Blog, then subsection: BlogDetailsSubsection) {
        showBlogDetails(for: blog)

        if let blogDetailsViewController = navigationController.topViewController as? BlogDetailsViewController {
            blogDetailsViewController.showDetailView(for: subsection)
        }
    }

    // MARK: - Stats

    func showStats(for blog: Blog) {
        showBlogDetails(for: blog, then: .stats)
    }

    func showStats(for blog: Blog, timePeriod: StatsPeriodType) {
        showBlogDetails(for: blog)

        if let blogDetailsViewController = navigationController.topViewController as? BlogDetailsViewController {
            // Setting this user default is a bit of a hack, but it's by far the easiest way to
            // get the stats view controller displaying the correct period. I spent some time
            // trying to do it differently, but the existing stats view controller setup is
            // quite complex and contains many nested child view controllers. As we're planning
            // to revamp that section in the not too distant future, I opted for this simpler
            // configuration for now. 2018-07-11 @frosty
            UserDefaults.standard.set(timePeriod.rawValue, forKey: MySitesCoordinator.statsPeriodTypeDefaultsKey)

            blogDetailsViewController.showDetailView(for: .stats)
        }
    }

    func showActivityLog(for blog: Blog) {
        showBlogDetails(for: blog, then: .activity)
    }

    private static let statsPeriodTypeDefaultsKey = "LastSelectedStatsPeriodType"

    // MARK: - Adding a new site

    @objc
    func showAddNewSite(from view: UIView) {
        showSitesList()

        blogListViewController.presentInterfaceForAddingNewSite(from: view)
    }

    // MARK: - My Sites

    func showPages(for blog: Blog) {
        showBlogDetails(for: blog, then: .pages)
    }

    func showPosts(for blog: Blog) {
        showBlogDetails(for: blog, then: .posts)
    }

    func showMedia(for blog: Blog) {
        showBlogDetails(for: blog, then: .media)
    }

    func showComments(for blog: Blog) {
        showBlogDetails(for: blog, then: .comments)
    }

    func showSharing(for blog: Blog) {
        showBlogDetails(for: blog, then: .sharing)
    }

    func showPeople(for blog: Blog) {
        showBlogDetails(for: blog, then: .people)
    }

    func showPlugins(for blog: Blog) {
        showBlogDetails(for: blog, then: .plugins)
    }

    func showManagePlugins(for blog: Blog) {
        guard blog.supports(.pluginManagement) else {
            return
        }

        // PerformWithoutAnimation is required here, otherwise the view controllers
        // potentially get added to the navigation controller out of order
        // (ShowDetailViewController, used by BlogDetailsViewController is animated)
        UIView.performWithoutAnimation {
            showBlogDetails(for: blog, then: .plugins)
        }

        guard let site = JetpackSiteRef(blog: blog),
            let navigationController = splitViewController.topDetailViewController?.navigationController else {
            return
        }

        let query = PluginQuery.all(site: site)
        let listViewController = PluginListViewController(site: site, query: query)

        navigationController.pushViewController(listViewController, animated: false)
    }
}
