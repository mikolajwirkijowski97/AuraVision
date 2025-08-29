- [x] Segmentation of live video feed using apples "Vision"
- [x] Create rudimental Metal shaders to create a godly aura effect based on segmentation result
- [ ] Create a wavey effect based on signed distance fields.
- [ ] Colorise the aura with shaders based on something that will give "mysterious" results -- probably some kind of a lightweight encoder-decoder network, and just use the latent space for RGB.
- [ ] Optimize if needed.
- [ ] Wrap in a nice ui.

Basically an **ML + Shaders** programming art project that has one goal - Look really damn nice, while being performant enough to run in "real-time" on any modern iOS device.

The project was initially based on this to skip through the boilerplate part:
# Live Camera SwiftUI

Code from the [video](https://www.youtube.com/watch?v=cLnw5z8ZGqM&t=22s) which shows how to read frames from a phone's camera and display the feed on the screen using SwiftUI, without UIKit.
