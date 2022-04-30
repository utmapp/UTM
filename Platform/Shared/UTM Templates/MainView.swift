//
//  MainView.swift
//  UTM Templates
//
//  Created by Christopher Mattar on 3/25/22.
//

import SwiftUI
import CoreData

@available(macOS 12.0, *)
struct MainView: View {
    
    @Environment(\.openURL) var openURL
    
    @State var showWarning = [false]
    @State var search = ""
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: HomeView()) {
                    Label("Home", systemImage: "house")
                }
                Section(header: Text("Official")) {
                    ForEach(officialVirtualMachines) { virtualMachine in
                        if virtualMachine.showSearch(search: search) {
                            NavigationLink(destination: DetailView(virtualMachine: virtualMachine)) {
                                HStack {
                                    Image(virtualMachine.image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20)
                                    Text(virtualMachine.title)
                                }
                            }
                        }
                    }
                }
                Section(header: Text("Original")) {
                    ForEach(originalVirtualMachines) { virtualMachine in
                        if virtualMachine.showSearch(search: search) {
                            NavigationLink(destination: DetailView(virtualMachine: virtualMachine)) {
                                HStack {
                                    Image(virtualMachine.image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20)
                                    Text(virtualMachine.title)
                                }
                            }
                        }
                    }
                }
                Section(header: Text("Verified Community Uploaded")) {
                    ForEach(verifiedCommunityUploadedVirtualMachines) { virtualMachine in
                        if virtualMachine.showSearch(search: search) {
                            NavigationLink(destination: DetailView(virtualMachine: virtualMachine)) {
                                HStack {
                                    Image(virtualMachine.image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20)
                                    Text(virtualMachine.title)
                                }
                            }
                        }
                    }
                }
                Section(header: Text("Unverified Community Uploaded")) {
                    ForEach(unverifiedCommunityUploadedVirtualMachines) { virtualMachine in
                        if virtualMachine.showSearch(search: search) {
                            NavigationLink(destination: DetailView(virtualMachine: virtualMachine)) {
                                HStack {
                                    Image("warning")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20)
                                        .help(Text("This VM has not been checked for viruses or corruption yet. Install at your own risk."))
                                    Image(virtualMachine.image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20)
                                    Text(virtualMachine.title)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .toolbar, prompt: "Search") {
                //                ForEach(officialVirtualMachines) { virtualMachine in
                //                    HStack {
                //                        Image(virtualMachine.image)
                //                            .resizable()
                //                            .aspectRatio(contentMode: .fit)
                //                            .frame(width: 20)
                //                        Text(virtualMachine.title)
                //                    }.searchCompletion(virtualMachine.title)
                //                }
                //                ForEach(originalVirtualMachines) { virtualMachine in
                //                    HStack {
                //                        Image(virtualMachine.image)
                //                            .resizable()
                //                            .aspectRatio(contentMode: .fit)
                //                            .frame(width: 20)
                //                        Text(virtualMachine.title)
                //                    }.searchCompletion(virtualMachine.title)
                //                }
                HStack {
                    Image("linux")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20)
                    Text("Linux")
                }
                .searchCompletion("Linux")
                HStack {
                    Image("windows")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20)
                    Text("Windows")
                }
                .searchCompletion("Windows")
                HStack {
                    Image("mac")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20)
                    Text("macOS")
                }
                .searchCompletion("macOS")
            }
            .navigationTitle("UTM Templates")
            .listStyle(.sidebar)
            .frame(minWidth: 180)
            
            HomeView()
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
