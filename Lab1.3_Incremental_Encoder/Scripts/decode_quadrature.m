function Q = decode_quadrature(a, b, threshold)
%% DECODE_QUADRATURE Software (polling) X4 decoder for sampled A/B channels.
%
% Syntax:
%   Q = decode_quadrature(a, b, threshold)
%
% a, b       channel A and B samples (ADC counts or volts), one sample per poll
% threshold  logic threshold in the same unit as a and b
%
% Output struct Q:
%   Q.A, Q.B     logic levels (true = high)
%   Q.state      Gray-code state 0..3 for (A,B) = 00, 10, 11, 01
%   Q.step       per-sample step: +1 = A leads B, -1 = B leads A, 0 = no change,
%                NaN = illegal jump (both channels changed between two polls,
%                so the direction and one state were lost)
%   Q.count      accumulated count from the legal steps only
%   Q.nLegal     number of legal state changes
%   Q.nIllegal   number of illegal jumps
%   Q.dwell      samples spent in each state between changes
%
% A poll must see every state, so polling at fs can follow at most fs states/s.
%
% Compatible with MATLAB R2020a through R2026a.

A = a(:) > threshold;
B = b(:) > threshold;
state = zeros(size(A));
state(A & ~B) = 1;
state(A & B)  = 2;
state(~A & B) = 3;

d = mod(diff(state), 4);
step = zeros(size(d));
step(d == 1) = 1;
step(d == 3) = -1;
step(d == 2) = NaN;

legal = step;
legal(isnan(legal)) = 0;
changes = find(d ~= 0);

Q.A        = A;
Q.B        = B;
Q.state    = state;
Q.step     = [0; step];
Q.count    = [0; cumsum(legal)];
Q.nLegal   = nnz(d == 1 | d == 3);
Q.nIllegal = nnz(d == 2);
Q.dwell    = diff(changes);
end
