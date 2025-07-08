import UIKit

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
        setupTabBarAppearance()
    }
    
    private func setupViewControllers() {
        let homeVC = createNavController(
            viewController: HomeViewController(),
            title: "Home",
            imageName: "house.fill"
        )
        
        let searchVC = createNavController(
            viewController: SearchViewController(),
            title: "Search",
            imageName: "magnifyingglass"
        )
        
        let favoritesVC = createNavController(
            viewController: FavoritesViewController(),
            title: "Favorites",
            imageName: "heart.fill"
        )
        
        let chatVC = createNavController(
            viewController: ChatViewController(),
            title: "Messages",
            imageName: "message.fill"
        )
        
        let profileVC = createNavController(
            viewController: ProfileViewController(),
            title: "Profile",
            imageName: "person.fill"
        )
        
        viewControllers = [homeVC, searchVC, favoritesVC, chatVC, profileVC]
        
        // Set default selected tab
        selectedIndex = 0
    }
    
    private func createNavController(viewController: UIViewController, title: String, imageName: String) -> UINavigationController {
        let navController = UINavigationController(rootViewController: viewController)
        navController.tabBarItem.title = title
        navController.tabBarItem.image = UIImage(systemName: imageName)
        navController.navigationBar.prefersLargeTitles = true
        viewController.navigationItem.title = title
        return navController
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = Theme.Colors.primary
    }
}