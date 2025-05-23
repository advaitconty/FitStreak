//
//  MapTrackingView.swift
//  gymguru
//
//  Created by Milind Contractor on 23/11/23.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreMotion
import DeviceKit
import Foundation
import Combine
import CoreMotion
import Combine

class MotionManager: ObservableObject {
    private var motionManager: CMMotionManager
    private var timer: Timer?
    
    @Published var speed: Double = 0.0
    
    private var velocityX: Double = 0.0
    private var velocityY: Double = 0.0
    private var velocityZ: Double = 0.0
    
    private var lastUpdateTime: Date?
    
    init() {
        self.motionManager = CMMotionManager()
        self.motionManager.accelerometerUpdateInterval = 1.0 / 60.0
    }
    
    func startUpdates() {
        if self.motionManager.isAccelerometerAvailable {
            self.motionManager.startAccelerometerUpdates()
            
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
                if let data = self.motionManager.accelerometerData {
                    self.processAccelerometerData(data)
                }
            }
        }
    }
    
    func stopUpdates() {
        self.motionManager.stopAccelerometerUpdates()
        self.timer?.invalidate()
        self.timer = nil
    }
    
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let currentTime = Date()
        
        guard let lastUpdateTime = self.lastUpdateTime else {
            self.lastUpdateTime = currentTime
            return
        }
        
        let deltaTime = currentTime.timeIntervalSince(lastUpdateTime)
        
        let accelerationX = data.acceleration.x * 9.81 // Convert to m/s^2
        let accelerationY = data.acceleration.y * 9.81
        let accelerationZ = data.acceleration.z * 9.81
        
        self.velocityX += accelerationX * deltaTime
        self.velocityY += accelerationY * deltaTime
        self.velocityZ += accelerationZ * deltaTime
        
        let velocity = sqrt(pow(self.velocityX, 2) + pow(self.velocityY, 2) + pow(self.velocityZ, 2))
        self.speed = velocity * 3.6 // Convert m/s to km/h
        
        self.lastUpdateTime = currentTime
    }
}


struct TimerDisplayObject {
    var seconds: Int = 0
    var minutes: Int = 0
    var hours: Int = 0
    
    var display: String {
        if self.seconds == 0 {
            "\(String(format: "%02d", self.hours)):\(String(format: "%02d", self.minutes)):00"
        } else {
            "\(String(format: "%02d", self.hours)):\(String(format: "%02d", self.minutes)):\(String(format: "%02d", self.seconds))"
        }
    }
    
    var timeMinuteCalculator: Float { Float(hours*60+seconds/60+minutes) }
}
struct MapTrackingView: View {
    @State var showStats = false
    @State var isTimerRunning = false
    @State var timer: Timer?
    @Namespace var namespace
    @State var position: MapCameraPosition = .automatic
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Namespace var mapscope
    @StateObject var locationManager = NewLocationManager()
    @StateObject var motionManager = NewMotionManager()
    let updateInterval = 0.1
    @State var timeElapsed: TimerDisplayObject = TimerDisplayObject()
    @State var timerDisplay = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Binding var userData: UserInfo
    @Environment(\.dismiss) var dismiss
    @State var showAlert = false
    @Binding var exercise: Exercise
    @State var issues = false
    @AppStorage("locationAccessStatus") var locationAccessStatus = false
    @State var keepScreenOn = true
    @State var iphoneSFSymbol: String = ""
    @State var isFirstLaunch: Bool = UserDefaults.standard.bool(forKey: "isFirstLaunch") == false
    
    func startMotionUpdates() {
        motionManager.startUpdates()
    }
    
    func stopMotionUpdates() {
        motionManager.stopUpdates()
    }
    
    var buttons: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Spacer()
                if isTimerRunning {
                    Button {
                        stopMotionUpdates()
                        isTimerRunning = false
                        locationManager.pauseLocationUpdates()
                    } label: {
                        Image(systemName: "pause.fill")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .matchedGeometryEffect(id: "Pause Button", in: namespace)
                } else {
                    Button {
                        locationManager.resumeLocationUpdates()
                        startMotionUpdates()
                        isTimerRunning = true
                        timeElapsed.seconds -= 1
                    } label: {
                        Image(systemName: "play.fill")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .matchedGeometryEffect(id: "Play Button", in: namespace)
                }
                Spacer()
            }
            .onAppear {
                if Device.current.isOneOf([.iPhone14Pro, .iPhone14ProMax, .iPhone15, .iPhone15Pro, .iPhone15Plus, .iPhone15ProMax]) {
                    iphoneSFSymbol = "iphone.gen3"
                } else if Device.current.isOneOf([.iPhoneSE2, .iPhoneSE3]) {
                    iphoneSFSymbol = "iphone.gen1"
                } else {
                    iphoneSFSymbol = "iphone.gen2"
                }
            }
        }
    }
    
    var body: some View {
        Group {
            if !showStats {
                VStack {
                    VStack {
                        Map(position: $position, scope: mapscope) {
                            UserAnnotation()
                            ForEach(locations, id: \.id) { location in
                                Marker(location.name, systemImage: location.icon, coordinate: location.location)
                                    .tint(location.colour)
                            }
                        }
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                        MapPitchToggle()
                    }
                    .safeAreaInset(edge: .bottom) {
                        ZStack {
                            buttons
                            
                            HStack {
                                Button {
                                    showAlert = true
                                } label: {
                                    Image(systemName: "stop.fill")
                                        .frame(width: 30, height: 30)
                                }
                                .buttonStyle(.bordered)
                                .matchedGeometryEffect(id: "Stop button", in: namespace)
                                Spacer()
                                Button {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        showStats = true
                                    }
                                } label: {
                                    Image(systemName: "chart.xyaxis.line")
                                        .frame(width: 30, height: 30)
                                }
                                .buttonStyle(.bordered)
                                .matchedGeometryEffect(id: "Graph button", in: namespace)
                            }
                        }
                        .padding()
                        .background(.thinMaterial)
                    }
                    .mapStyle(.hybrid(elevation: .realistic, showsTraffic: true))
                    .transition(.slide)
                    .mapControlVisibility(.visible)
                    .mapScope(mapscope)
                }
            } else {
                VStack {
                    VStack {
                        Spacer()
                        Text(timeElapsed.display)
                            .font(.system(size: 55))
                            .fontWidth(.expanded)
                        Text("TIME")
                            .font(.system(size: 20))
                            .fontWidth(.expanded)
                        Divider()
                        Text("\(motionManager.speed, specifier: "%.2f") km/h")
                            .font(.system(size: 55))
                            .fontWidth(.expanded)
                        Text("SPEED")
                            .font(.system(size: 20))
                            .fontWidth(.expanded)
                        Divider()
                        Text("\(String(format: "%.2f", locationManager.getTotalDistanceTravelled())) km")
                            .font(.system(size: 55))
                            .fontWidth(.expanded)
                        Text("DISTANCE")
                            .font(.system(size: 20))
                            .fontWidth(.expanded)
                        Spacer()
                    }
                    .safeAreaInset(edge: .bottom) {
                        ZStack {
                            buttons
                            
                            HStack {
                                Button {
                                    showAlert = true
                                } label: {
                                    Image(systemName: "stop.fill")
                                        .frame(width: 30, height: 30)
                                }
                                .buttonStyle(.bordered)
                                .matchedGeometryEffect(id: "Stop button", in: namespace)
                                Spacer()
                                Button {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        showStats = false
                                    }
                                } label: {
                                    Image(systemName: "chart.xyaxis.line")
                                        .frame(width: 30, height: 30)
                                }
                                .buttonStyle(.borderedProminent)
                                .matchedGeometryEffect(id: "Graph button", in: namespace)
                            }
                        }
                        .padding()
                        .background(.thinMaterial)
                    }
                    .safeAreaInset(edge: .top) {
                        HStack {
                            Spacer()
                            Button {
                                showAlert = true
                            } label: {
                                Image(systemName: "stop.fill")
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.bordered)
                            .matchedGeometryEffect(id: "Stop button", in: namespace)
                            .frame(width: 30, height: 30)
                        }
                        .padding()
                        .background(.thinMaterial)
                    }
                }
                .transition(.slide)
            }
        }
        .onReceive(timerDisplay) { _ in
            if isTimerRunning {
                timeElapsed.seconds += 1
                if timeElapsed.seconds == 60 {
                    timeElapsed.seconds = 0
                    timeElapsed.minutes += 1
                    if timeElapsed.minutes == 60 {
                        timeElapsed.minutes = 0
                        timeElapsed.hours += 1
                    }
                }
            }
        }
        .alert("Are you sure you want to end this workout?", isPresented: $showAlert) {
            Button("OK", role: .destructive) {
                for (challengeIndex, challenge) in userData.challengeData.enumerated() {
                    for (workoutIndex, workout) in challenge.challengeItems.enumerated() {
                        if workout.workoutItem == exercise {
                            userData.challengeData[challengeIndex].challengeItems[workoutIndex].completed += Float(locationManager.getTotalDistanceTravelled())
                        }
                    }
                }
                for (dailyChallengeIndex, dailyChallenge) in userData.dailyChallenge.challengeItems.enumerated() {
                    if dailyChallenge.workoutItem == exercise {
                        userData.dailyChallenge.challengeItems[dailyChallengeIndex].completed += Float(locationManager.getTotalDistanceTravelled())
                    }
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {  }
        }
        .sheet(isPresented: $issues) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Why is my tracking not working?")
                    .font(.headline)
                Text("Please check your app settings as you may have disabled location access for this app or your location services have been turned off. Tracking may also not work because of location accuracy issues in places deep underground (e.g., tunnels, etc.).")
            }
            .padding()
        }
        .onAppear {
            locationManager.pauseLocationUpdates()
        }
    }
}
