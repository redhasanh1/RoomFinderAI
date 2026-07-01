import SwiftUI
import Supabase

struct RealtimeTestView: View {
    @Environment(\.supabase) private var supabase
    @StateObject private var realtime = ListingsRealtime()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Connection Status
                HStack {
                    Circle()
                        .fill(realtime.isConnected ? .green : .red)
                        .frame(width: 12, height: 12)
                    
                    Text(realtime.connectionStatus)
                        .font(.headline)
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Controls
                HStack {
                    Button(realtime.isConnected ? "Disconnect" : "Connect") {
                        if realtime.isConnected {
                            realtime.stop()
                        } else {
                            realtime.start(using: supabase)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Clear Log") {
                        realtime.clearLog()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
                
                // Events Log
                Text("Realtime Events Log")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if realtime.eventsLog.isEmpty {
                    Text("No events yet. Connect to start monitoring.")
                        .foregroundColor(.secondary)
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(realtime.eventsLog.enumerated().reversed()), id: \.offset) { index, event in
                                HStack {
                                    Text("\(realtime.eventsLog.count - index)")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                        .frame(width: 30)
                                    
                                    Text(event)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                                .padding(.horizontal, 8)
                                .background(index % 2 == 0 ? Color(.systemGray6) : Color.clear)
                                .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Realtime Test")
            .onAppear {
                realtime.start(using: supabase)
            }
            .onDisappear {
                realtime.stop()
            }
        }
    }
}

#Preview {
    RealtimeTestView()
        .environment(\.supabase, SupabaseFactory.makeClient())
}