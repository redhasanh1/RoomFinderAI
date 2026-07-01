import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Text("Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Sign in to your Room Finder AI account")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                Button(action: {
                    authViewModel.signIn()
                }) {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(authViewModel.isLoading)
                
                if authViewModel.isLoading {
                    ProgressView()
                        .padding()
                }
                
                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Button("Don't have an account? Sign Up") {
                    showingSignUp = true
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Login")
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}