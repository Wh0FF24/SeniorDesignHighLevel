import SwiftUI
import PlaygroundSupport

// SplashScreen remains the same
struct SplashScreen: View {
    @State private var isActive = false
    
    var body: some View {
        VStack {
            if isActive {
                ContentView()
            } else {
                VStack {
                    Text("H.E.T.A.P - S.E.A.T")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Image("Hetap")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .shadow(radius: 10)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            isActive = true
                        }
                    }
                }
            }
        }
    }
}



// Main ContentView with gold and black gradient background
struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Button(action: {
                    // Action for Start Mapping
                }) {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                            .font(.title)
                        Text("Start Mapping")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(ModuleButtonStyle())
                
                NavigationLink(destination: MapTrailView()) {
                    HStack {
                        Image(systemName: "map")
                            .font(.title)
                        Text("Map View")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(ModuleButtonStyle())
                
                Button("Offline Maps") {
                    // Placeholder action for Offline Maps
                }
                .buttonStyle(ModuleButtonStyle())
                .overlay(
                    HStack {
                        Image(systemName: "wifi.slash")
                            .font(.title)
                        Spacer()
                    }
                        .padding(.leading, 16)
                )
                
                NavigationLink(destination: ArcGisUploadView()) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.title)
                        Text("Upload Data")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(ModuleButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 20)
            .background(LinearGradient(gradient: Gradient(colors: [.black, Color(red: 1.0, green: 0.84, blue: 0.0)]), startPoint: .top, endPoint: .bottom))
            .edgesIgnoringSafeArea(.all)
            .navigationTitle("H.E.T.A.P. - S.E.A.T.")
            .navigationBarItems(leading: UserProfileButton(), trailing: SettingsButton())
            .onAppear {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.titleTextAttributes = [.foregroundColor: UIColor.red, .font: UIFont.boldSystemFont(ofSize: 24)]
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
            }
            .onDisappear {
                UINavigationBar.appearance().standardAppearance = UINavigationBarAppearance()
                UINavigationBar.appearance().compactAppearance = UINavigationBarAppearance()
                UINavigationBar.appearance().scrollEdgeAppearance = UINavigationBarAppearance()
            }
        }
    }
}

struct ModuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding()
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut, value: configuration.isPressed)
    }
}

struct UserProfileButton: View {
    var body: some View {
        Button(action: {
            // Handle user profile action
        }) {
            Image(systemName: "person.crop.circle")
                .font(.title)
        }
    }
}

struct SettingsButton: View {
    var body: some View {
        NavigationLink(destination: SettingsView()) {
            Image(systemName: "gearshape")
                .font(.title)
        }
    }
}
