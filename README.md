# sm-browser-client

WIP UI for browsing the StreamMachine Rewind Buffer and exporting selections
from it.

Currently just a static site that assumes [sm-archiver](https://github.com/StreamMachine/sm-archiver)
is running on localhost:8005 and that you have a stream named `kpcc`. Change
the URL in `main.coffee` to fit your needs.

Requires node to generate assets. `npm install` and then `gulp serve` to run.

# Concept

Visualize the Rewind Buffer using discrete waveforms for the HLS segments
StreamMachine is already creating. Render those waveforms into what looks
like a single display.

Eventually the goal is to set in and out points and then allow you to trigger
an audio export from the server.
