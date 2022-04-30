//
//  HomeView.swift
//  UTM Templates
//
//  Created by Christopher Mattar on 3/25/22.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack {
            Text("UTM Templates")
                .font(.largeTitle)
                .padding(.bottom, 1)
            Text("A few preinstalled templates for use with UTM for Mac with Apple Silicon.")
                .font(.title)
                .padding(.bottom, 1)
            Text("Click on a VM that you would like to run in the sidebar, then click on \"Download VM\". Finally, double-click the downloaded file to open it in UTM.")
            Spacer()
        }
        .padding()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
