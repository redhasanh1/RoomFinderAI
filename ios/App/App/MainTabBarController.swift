import UIKit

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        createTabs()
    }
    
    private func setupTabBar() {
        // Configure tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.backgroundColor
        
        // Configure normal state
        appearance.stackedLayoutAppearance.normal.iconColor = AppColors.textSecondary
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: AppColors.textSecondary,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]
        
        // Configure selected state
        appearance.stackedLayoutAppearance.selected.iconColor = AppColors.primaryPurple
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: AppColors.primaryPurple,
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]
        
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        
        // Add subtle shadow
        tabBar.layer.shadowColor = UIColor.black.cgColor
        tabBar.layer.shadowOpacity = 0.1
        tabBar.layer.shadowOffset = CGSize(width: 0, height: -1)
        tabBar.layer.shadowRadius = 4
    }
    
    private func createTabs() {
        let homeVC = createNavigationController(
            rootViewController: HomeViewController(),
            title: "Home",
            imageName: "house.fill"
        )
        
        let searchVC = createNavigationController(
            rootViewController: SearchViewController(),
            title: "Search",
            imageName: "magnifyingglass"
        )
        
        let favoritesVC = createNavigationController(
            rootViewController: FavoritesViewController(),
            title: "Favorites",
            imageName: "heart.fill"
        )
        
        let chatVC = createNavigationController(
            rootViewController: ChatViewController(),
            title: "AI Chat",
            imageName: "message.fill"
        )
        
        let profileVC = createNavigationController(
            rootViewController: ProfileViewController(),
            title: "Profile",
            imageName: "person.fill"
        )
        
        viewControllers = [homeVC, searchVC, favoritesVC, chatVC, profileVC]
    }
    
    private func createNavigationController(rootViewController: UIViewController, title: String, imageName: String) -> UINavigationController {
        let navController = UINavigationController(rootViewController: rootViewController)
        navController.tabBarItem.title = title
        navController.tabBarItem.image = UIImage(systemName: imageName)
        
        // Configure navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.backgroundColor
        appearance.titleTextAttributes = [
            .foregroundColor: AppColors.textPrimary,
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: AppColors.textPrimary,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        navController.navigationBar.standardAppearance = appearance
        navController.navigationBar.compactAppearance = appearance
        navController.navigationBar.scrollEdgeAppearance = appearance
        navController.navigationBar.tintColor = AppColors.primaryPurple
        navController.navigationBar.prefersLargeTitles = true
        
        return navController
    }
}