//
//  DetailView.swift
//  UTM Templates
//
//  Created by Christopher Mattar on 3/25/22.
//

import SwiftUI


@available(macOS 12.0, *)
struct DetailView: View {
    
    @EnvironmentObject var data: UTMData
    
    var virtualMachine: VirtualMachine
    
    var body: some View {
        VStack {
            Text(virtualMachine.title)
                .font(.largeTitle)
            if virtualMachine.verified == true {
                HStack {
                    Image("checkmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80)
                    Text("This virtual machine is safe to install because it was checked by a developer or contributor of UTM or UTM Templates.")
                        .font(.title2)
                }
            }
            if virtualMachine.verified == false {
                HStack {
                    Image("warning")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80)
                    Text("This virtual machine is community uploaded and has not been checked for viruses or corruption yet. Install at your own risk.")
                        .font(.title2)
                }
            }
            if virtualMachine.verified == nil {
                HStack {
                    Image("checkmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80)
                    Text("This virtual machine is safe to install because it was built by a developer or contributor of UTM or UTM Templates.")
                        .font(.title2)
                }
            }
            Table(virtualMachine.attributes) {
                TableColumn("") { attr in
                    Text(attr.key)
                        .bold()
                }
                TableColumn("") { attr in
                    Text(attr.value)
                }
            }
            if virtualMachine.instructions != "" {
                Text("Instructions")
                    .font(.title2)
                Text(try! AttributedString(markdown: virtualMachine.instructions))
            }
            HStack {
                Button(action: {
                    if let url = URL(string: "\(virtualMachine.link)/content") {
                        print("VM")
                        data.downloadUTMZip(from: URLComponents(url: URL(string: "utm://downloadVM?url=\(url.absoluteString)")!, resolvingAgainstBaseURL: false)!)
                    }
                    else {
                        print("NO VM")
                    }
                }) {
                    Text("Add VM")
                        .padding(8)
                        .background(Color.blue)
                        .cornerRadius(5)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding()
    }
}

@available(macOS 12.0, *)
struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        DetailView(virtualMachine: officialVirtualMachines.last!).padding()
    }
}
