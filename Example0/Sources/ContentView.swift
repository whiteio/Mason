//
//  ContentView.swift
//  Example
//
//  Created by Chris White on 1/26/25.
//

import ModuleA
import ModuleC
import SwiftUI
import UIKit

struct ContentView: View {
  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("Hello, woooorld!")
      Text(World().example)
      Text(Example().example)
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
