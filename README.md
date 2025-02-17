# AER development for testing CPG

Developing an AER handshaking protocol for testing CPG (an specific neuromorphic chip).

Address-event representation (AER) was proposed in 1991 by Sivilotti for trans-
ferring the state of an array of neurons from one chip to another. AER is a commu-
nication protocol originally proposed as a means to communicate sparse neural events
between neuromorphic chips. The block diagram in Figure 1 shows the organization of
the various AER blocks within two-dimensionally organized transmitter and receiver
chips. The signal flow between any two communicating blocks is carried out through the
Request (Req) and Acknowledge (Ack) signals. Figure 2 illustrates the 4-phases hand-
shaking protocol which we used in this project. Steps : 1) Both Req and Ack are initially
in zero states. 2) A new data word is put on the bus, and Req is raised, and control is
passed to the receiver. 3) When ready, the receiver accepts the data and raises Ack. 4)
Req and Ack are brought back to their initial state in sequence. We use the same AER
communication protocol to send the neuromorphic biases as well as monitor the events
using a PC. Therefore we need to interface the chip and the PC using an FPGA which
hosts an AER core.
