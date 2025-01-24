//
//  LocationDetailView.swift
//  SHPE-UF-Mobile-Swift
//
//  Created by Matthew Segura on 12/21/24.
//
import SwiftUI
import MapKit
import SwiftData

struct LocationDetailView: View{
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager:LocationManager
    
    @Binding var destinationCoordinate: CLLocationCoordinate2D?
    var selectedPlacemark : MTPlacemark?
    @Binding var showRoute: Bool
    @Binding var widgetOffset: CGFloat
    @Binding var travelInterval: TimeInterval?
    @Binding var transportType: MKDirectionsTransportType
    @Binding var cameraPosition: MapCameraPosition
    @Binding var region: MKCoordinateRegion
    @Binding var routeDestination: MKMapItem?
    @Binding var route: MKRoute?
    
//    @StateObject private var locationManager:LocationManager = LocationManager()
    
    var travelTime: String?{
        guard let travelInterval else{return nil}
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour,.minute]
        return formatter.string(from: travelInterval)
    }
    @State private var name = ""
    @State private var address = ""
    @State private var type =  MKDirectionsTransportType.automobile
    @State private var lookaroundScene: MKLookAroundScene?
    
    @State private var showMapsSheet: Bool = false
    
    var body: some View{
        VStack{
            HStack{
                VStack(alignment: .leading){
                    HStack(alignment: .center)
                    {
                        Spacer()
                        RoundedRectangle(cornerRadius: 2)
                            .frame(width: 50,height: 4)
                            .background(.gray.opacity(0.5))
                        Spacer()
                    }
                    .frame(maxWidth:.infinity)
                    
                    Text(name)
                        .font(.title2)
                        .lineLimit(1)
                        .fontWeight(.semibold)
                    Text(address)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                    if destinationCoordinate != nil{
                        
                        HStack{
                            Button{
                                transportType = .automobile // There is double as to show time when first appears and still keep binding variable updated for route type
                                type = .automobile
                            }label:{
                                Image(systemName:"car")
                                    .foregroundColor(type == .automobile ? .blue: .lorange)
                                    .imageScale(.large)
                            }
                            Button{
                                transportType = .walking
                                type = .walking
                            }label:{
                                Image(systemName:"figure.walk")
                                    .foregroundColor(type == .walking ? .blue : .lorange)
                                    .imageScale(.large)
                            }
                            
                            if let travelTime,
                               locationManager.userLocation != nil
                            {
                                let prefix = transportType == .automobile ? "Driving" : "Walking"
                                Text("\(prefix) time: \(travelTime)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            else
                            {
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                        }
                    }
                }
                
                Spacer()
            }
            if let lookaroundScene{
                LookAroundPreview(initialScene: lookaroundScene)
                    .frame(height:UIScreen.main.bounds.height * 0.2)
                    .padding()
            }else{
                ContentUnavailableView("No preview available", systemImage: "eye.slash")
                    .frame(height:UIScreen.main.bounds.height * 0.2)
                    .padding()
            }
            HStack{
                Spacer()
                if destinationCoordinate != nil
                {
                    Button("Open in maps",systemImage: "map"){
                        withAnimation {
                            showMapsSheet = true
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    
                    Button("Show Route", systemImage: "location.north"){
                        showRoute.toggle()
                        widgetOffset = 260
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .disabled(route == nil)
                }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
        .task(id: selectedPlacemark)
        {
            await fetchLookaroundPreview()
        }
        .task(id: locationManager.userLocation)
        {
            await fetchRoute()
        }
        .task(id: transportType)
        {
            await fetchRoute()
        }
        .onAppear{
            if let selectedPlacemark
            {
                name = selectedPlacemark.name
                address = selectedPlacemark.address
            }
        }
        .sheet(isPresented: $showMapsSheet, content: {
            VStack {
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 50,height: 4)
                    .background(.gray.opacity(0.5))
                    .padding(.vertical, 5)
                
                Spacer()
                
                Button(action: openInAppleMaps) {
                    HStack
                    {
                        Image(systemName: "applelogo")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding(5)
                            .foregroundColor(.white)
                            
                        Text("Open in Apple Maps")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .cornerRadius(8)
                }

                Divider()
                    .padding(.vertical, 8)

                Button(action: openInGoogleMaps) {
                    HStack
                    {
                        Image("google_logo")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding(5)
                        
                        Text("Open in Google Maps")
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                }
            }
            .padding()
            .presentationDetents([.fraction(0.27)])
        })
    }
    
    // Route fetching functions
    func fetchRoute() async{
        if let userLocation = locationManager.userLocation, let selectedPlacemark{
            let request = MKDirections.Request()
            let sourcePlacemark = MKPlacemark(coordinate: userLocation.coordinate)
            let routeSource = MKMapItem(placemark: sourcePlacemark)
            
            let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate ?? region.center)
            
            routeDestination = MKMapItem(placemark: destinationPlacemark)
            routeDestination?.name = selectedPlacemark.name
            request.source = routeSource
            request.destination = routeDestination
            request.transportType = transportType
            let directions = MKDirections(request: request)
            let result = try? await directions.calculate()
            route = result?.routes.first
            travelInterval = route?.expectedTravelTime
            print(travelInterval as Any)
        }
        else
        {
            print("Missing something...")
            print("User Location: ", locationManager.userLocation as Any)
            print("Selected Placemark: ",selectedPlacemark as Any)
        }
    }
    
    func updateCameraPosition(){
        if let userLocation = locationManager.userLocation{
            let userRegion = MKCoordinateRegion(
                center:userLocation.coordinate,
                span:MKCoordinateSpan(
                    latitudeDelta: 0.15,
                    longitudeDelta: 0.15
                
            ))
            withAnimation{
                cameraPosition = .region(userRegion)
            }
        }
    }
    
    func openInAppleMaps() {
        let latitude = selectedPlacemark!.latitude
        let longitude = selectedPlacemark!.longitude
        let name = selectedPlacemark!.name

        if let url = URL(string: "http://maps.apple.com/?q=\(name)&ll=\(latitude),\(longitude)") {
            UIApplication.shared.open(url)
        }
    }

    func openInGoogleMaps() {
        let latitude = selectedPlacemark!.latitude
        let longitude = selectedPlacemark!.longitude

        if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(latitude),\(longitude)") {
            UIApplication.shared.open(url)
        }
    }
    
    func fetchLookaroundPreview() async{
        if let destination = destinationCoordinate{
            lookaroundScene = nil
            let lookaroundRequest = MKLookAroundSceneRequest(coordinate: destination)
            lookaroundScene = try? await lookaroundRequest.scene
            
        }
    }
    
    
}
