# This file is part of Kpax3. License is MIT.

ε = eps()

settings = KSettings("typesmcmc.bin", 1, 0, 1, [1.0; 0.0; 0.0], 0.0, 1.0,
                     [0.6; 0.35; 0.05], 135.0, 1.0, 1.0, 5.0, 3, 1, true, 1)

data = UInt8[0x00 0x00 0x00 0x00 0x00 0x01;
             0x01 0x01 0x01 0x01 0x01 0x00;
             0x00 0x00 0x01 0x00 0x01 0x01;
             0x01 0x01 0x00 0x01 0x00 0x00;
             0x01 0x01 0x00 0x00 0x00 0x00;
             0x00 0x00 0x00 0x01 0x01 0x00;
             0x01 0x01 0x01 0x00 0x00 0x00;
             0x00 0x00 0x00 0x01 0x01 0x01;
             0x00 0x00 0x01 0x00 0x00 0x00;
             0x01 0x00 0x00 0x01 0x00 0x01;
             0x00 0x01 0x00 0x00 0x01 0x00;
             0x00 0x00 0x00 0x00 0x00 0x01;
             0x01 0x01 0x01 0x00 0x00 0x00;
             0x00 0x00 0x00 0x01 0x01 0x00;
             0x01 0x01 0x00 0x00 0x01 0x01;
             0x00 0x00 0x01 0x01 0x00 0x00;
             0x01 0x01 0x00 0x01 0x00 0x00;
             0x00 0x00 0x01 0x00 0x01 0x01]

m, n = size(data)

R = [13; 13; 13; 42; 42; 76]
k = length(unique(R))

priorR = EwensPitman(settings.α, settings.θ)
priorC = AminoAcidPriorCol(data, k, settings.γ, settings.r)

ij = [4; 6]
S = 1
u = 5

# test merge functions by merging cluster 2 and cluster 3
mergesupport = KSupport(m, n, settings.maxclust, settings.maxunit)
mergelogω = [0.0; 0.0; log(k - 2.0) - log(k - 1.0); -log(k - 1.0)]

initsupport!(ij, S, k - 1, data, mergelogω, priorC, mergesupport)

wi = zeros(Float64, 4, m)
for col in 1:m
  for row in 1:4
    wi[row, col] = priorC.logγ[row] + mergelogω[row] +
                   logmarglik(data[col, ij[1]], 1, priorC.A[row, col],
                              priorC.B[row, col])
  end
end

ci = [log(sum(exp(mergesupport.wi.w[:, b])))::Float64 for b in 1:m]

@test mergesupport.vi == 1
@test mergesupport.ni == float(data[:, ij[1]])
@test mergesupport.ui == [ij[1]; 0]
@test maximum(abs(mergesupport.wi.w - wi)) <= ε
@test maximum(abs(mergesupport.wi.c - ci)) <= ε
@test mergesupport.wi.z == zeros(Float64, 4, m)

wj = zeros(Float64, 4, m)
for col in 1:m
  for row in 1:4
    wj[row, col] = priorC.logγ[row] + mergelogω[row] +
                   logmarglik(data[col, ij[2]], 1, priorC.A[row, col],
                              priorC.B[row, col])
  end
end

cj = [log(sum(exp(mergesupport.wj.w[:, b])))::Float64 for b in 1:m]

@test mergesupport.vj == 1
@test mergesupport.nj == float(data[:, ij[2]])
@test mergesupport.uj == [ij[2]; 0]
@test maximum(abs(mergesupport.wj.w - wj)) <= ε
@test maximum(abs(mergesupport.wj.c - cj)) <= ε
@test mergesupport.wj.z == zeros(Float64, 4, m)

# move unit u to cluster 2
mergesupport = KSupport(m, n, settings.maxclust, settings.maxunit)
initsupport!(ij, S, k - 1, data, mergelogω, priorC, mergesupport)
lcp = zeros(Float64, 2)
for b in 1:m
  lcp[1] += computeclusteriseqprobs!(data[b, u], b, priorC, mergesupport)
  lcp[2] += computeclusterjseqprobs!(data[b, u], b, priorC, mergesupport)
end
updateclusteri!(u, data, mergesupport)

wi = zeros(Float64, 4, m)
for col in 1:m
  for row in 1:4
    wi[row, col] = priorC.logγ[row] + mergelogω[row] +
                   logmarglik(data[col, ij[1]], 1, priorC.A[row, col],
                              priorC.B[row, col]) +
                   logcondmarglik(data[col, u], data[col, ij[1]], 1,
                                  priorC.A[row, col], priorC.B[row, col])
  end
end
zi = copy(wi)

ci = [log(sum(exp(mergesupport.wi.w[:, b])))::Float64 for b in 1:m]

@test mergesupport.vi == 2
@test mergesupport.ni == float(data[:, ij[1]]) + float(data[:, u])
@test mergesupport.ui == [ij[1]; u]
@test maximum(abs(mergesupport.wi.w - wi)) <= ε
@test maximum(abs(mergesupport.wi.c - ci)) <= ε
@test maximum(abs(mergesupport.wi.z - zi)) <= ε

wj = zeros(Float64, 4, m)
zj = zeros(Float64, 4, m)
for col in 1:m
  for row in 1:4
    zj[row, col] = priorC.logγ[row] + mergelogω[row] +
                   logmarglik(data[col, ij[2]], 1, priorC.A[row, col],
                              priorC.B[row, col]) +
                   logcondmarglik(data[col, u], data[col, ij[2]], 1,
                                  priorC.A[row, col], priorC.B[row, col])
    wj[row, col] = priorC.logγ[row] + mergelogω[row] +
                   logmarglik(data[col, ij[2]], 1, priorC.A[row, col],
                              priorC.B[row, col])
  end
end

cj = [log(sum(exp(mergesupport.wj.w[:, b])))::Float64 for b in 1:m]

@test mergesupport.vj == 1
@test mergesupport.nj == float(data[:, ij[2]])
@test mergesupport.uj == [ij[2]; 0]
@test maximum(abs(mergesupport.wj.w - wj)) <= ε
@test maximum(abs(mergesupport.wj.c - cj)) <= ε
@test maximum(abs(mergesupport.wj.z - zj)) <= ε

# move unit u to cluster 3
mergesupport = KSupport(m, n, settings.maxclust, settings.maxunit)
initsupport!(ij, S, k - 1, data, mergelogω, priorC, mergesupport)
lcp = zeros(Float64, 2)
for b in 1:m
  lcp[1] += computeclusteriseqprobs!(data[b, u], b, priorC, mergesupport)
  lcp[2] += computeclusterjseqprobs!(data[b, u], b, priorC, mergesupport)
end
updateclusterj!(u, data, mergesupport)

wi = zeros(Float64, 4, m)
zi = zeros(Float64, 4, m)
for col in 1:m
  for row in 1:4
    zi[row, col] = priorC.logγ[row] + mergelogω[row] +
                   logmarglik(data[col, ij[1]], 1, priorC.A[row, col],
                              priorC.B[row, col]) +
                   logcondmarglik(data[col, u], data[col, ij[1]], 1,
                                  priorC.A[row, col], priorC.B[row, col])
    wi[row, col] = priorC.logγ[row] + mergelogω[row] +
                   logmarglik(data[col, ij[1]], 1, priorC.A[row, col],
                              priorC.B[row, col])
  end
end

ci = [log(sum(exp(mergesupport.wi.w[:, b])))::Float64 for b in 1:m]

@test mergesupport.vi == 1
@test mergesupport.ni == float(data[:, ij[1]])
@test mergesupport.ui == [ij[1]; 0]
@test maximum(abs(mergesupport.wi.w - wi)) <= ε
@test maximum(abs(mergesupport.wi.c - ci)) <= ε
@test maximum(abs(mergesupport.wi.z - zi)) <= ε

wj = zeros(Float64, 4, m)
for col in 1:m
  for row in 1:4
    wj[row, col] = priorC.logγ[row] + mergelogω[row] +
                   logmarglik(data[col, ij[2]], 1, priorC.A[row, col],
                              priorC.B[row, col]) +
                   logcondmarglik(data[col, u], data[col, ij[2]], 1,
                                  priorC.A[row, col], priorC.B[row, col])
  end
end
zj = copy(wj)

cj = [log(sum(exp(mergesupport.wj.w[:, b])))::Float64 for b in 1:m]

@test mergesupport.vj == 2
@test mergesupport.nj == float(data[:, ij[2]]) + float(data[:, u])
@test mergesupport.uj == [ij[2]; u]
@test maximum(abs(mergesupport.wj.w - wj)) <= ε
@test maximum(abs(mergesupport.wj.c - cj)) <= ε
@test maximum(abs(mergesupport.wj.z - zj)) <= ε

# test split functions by splitting cluster 1
splitsupport = KSupport(m, n, settings.maxclust, settings.maxunit)
splitlogω = [0.0; 0.0; log(k) - log(k + 1.0); -log(k + 1.0)]

initsupport!(ij, S, k + 1, data, splitlogω, priorC, splitsupport)

wi = zeros(Float64, 4, m)
for col in 1:m
  for row in 1:4
    wi[row, col] = priorC.logγ[row] + splitlogω[row] +
                   logmarglik(data[col, ij[1]], 1, priorC.A[row, col],
                              priorC.B[row, col])
  end
end

ci = [log(sum(exp(splitsupport.wi.w[:, b])))::Float64 for b in 1:m]

@test splitsupport.vi == 1
@test splitsupport.ni == float(data[:, ij[1]])
@test splitsupport.ui == [ij[1]; 0]
@test maximum(abs(splitsupport.wi.w - wi)) <= ε
@test maximum(abs(splitsupport.wi.c - ci)) <= ε
@test splitsupport.wi.z == zeros(Float64, 4, m)

wj = zeros(Float64, 4, m)
for col in 1:m
  for row in 1:4
    wj[row, col] = priorC.logγ[row] + splitlogω[row] +
                   logmarglik(data[col, ij[2]], 1, priorC.A[row, col],
                              priorC.B[row, col])
  end
end

cj = [log(sum(exp(splitsupport.wj.w[:, b])))::Float64 for b in 1:m]

@test splitsupport.vj == 1
@test splitsupport.nj == float(data[:, ij[2]])
@test splitsupport.uj == [ij[2]; 0]
@test maximum(abs(splitsupport.wj.w - wj)) <= ε
@test maximum(abs(splitsupport.wj.c - cj)) <= ε
@test splitsupport.wj.z == zeros(Float64, 4, m)

# move unit u to cluster 2
spitsupport = KSupport(m, n, settings.maxclust, settings.maxunit)
initsupport!(ij, S, k + 1, data, splitlogω, priorC, splitsupport)
lcp = zeros(Float64, 2)
for b in 1:m
  lcp[1] += computeclusteriseqprobs!(data[b, u], b, priorC, splitsupport)
  lcp[2] += computeclusterjseqprobs!(data[b, u], b, priorC, splitsupport)
end
updateclusteri!(u, data, splitsupport)

wi = zeros(Float64, 4, m)
for col in 1:m
  for row in 1:4
    wi[row, col] = priorC.logγ[row] + splitlogω[row] +
                   logmarglik(data[col, ij[1]], 1, priorC.A[row, col],
                              priorC.B[row, col]) +
                   logcondmarglik(data[col, u], data[col, ij[1]], 1,
                                  priorC.A[row, col], priorC.B[row, col])
  end
end
zi = copy(wi)

ci = [log(sum(exp(splitsupport.wi.w[:, b])))::Float64 for b in 1:m]

@test splitsupport.vi == 2
@test splitsupport.ni == float(data[:, ij[1]]) + float(data[:, u])
@test splitsupport.ui == [ij[1]; u]
@test maximum(abs(splitsupport.wi.w - wi)) <= ε
@test maximum(abs(splitsupport.wi.c - ci)) <= ε
@test maximum(abs(splitsupport.wi.z - zi)) <= ε

wj = zeros(Float64, 4, m)
zj = zeros(Float64, 4, m)
for col in 1:m
  for row in 1:4
    zj[row, col] = priorC.logγ[row] + splitlogω[row] +
                   logmarglik(data[col, ij[2]], 1, priorC.A[row, col],
                              priorC.B[row, col]) +
                   logcondmarglik(data[col, u], data[col, ij[2]], 1,
                                  priorC.A[row, col], priorC.B[row, col])
    wj[row, col] = priorC.logγ[row] + splitlogω[row] +
                   logmarglik(data[col, ij[2]], 1, priorC.A[row, col],
                              priorC.B[row, col])
  end
end

cj = [log(sum(exp(splitsupport.wj.w[:, b])))::Float64 for b in 1:m]

@test splitsupport.vj == 1
@test splitsupport.nj == float(data[:, ij[2]])
@test splitsupport.uj == [ij[2]; 0]
@test maximum(abs(splitsupport.wj.w - wj)) <= ε
@test maximum(abs(splitsupport.wj.c - cj)) <= ε
@test maximum(abs(splitsupport.wj.z - zj)) <= ε

# move unit u to cluster 3
splitsupport = KSupport(m, n, settings.maxclust, settings.maxunit)
initsupport!(ij, S, k - 1, data, splitlogω, priorC, splitsupport)
lcp = zeros(Float64, 2)
for b in 1:m
  lcp[1] += computeclusteriseqprobs!(data[b, u], b, priorC, splitsupport)
  lcp[2] += computeclusterjseqprobs!(data[b, u], b, priorC, splitsupport)
end
updateclusterj!(u, data, splitsupport)

wi = zeros(Float64, 4, m)
zi = zeros(Float64, 4, m)
for col in 1:m
  for row in 1:4
    zi[row, col] = priorC.logγ[row] + splitlogω[row] +
                   logmarglik(data[col, ij[1]], 1, priorC.A[row, col],
                              priorC.B[row, col]) +
                   logcondmarglik(data[col, u], data[col, ij[1]], 1,
                                  priorC.A[row, col], priorC.B[row, col])
    wi[row, col] = priorC.logγ[row] + splitlogω[row] +
                   logmarglik(data[col, ij[1]], 1, priorC.A[row, col],
                              priorC.B[row, col])
  end
end

ci = [log(sum(exp(splitsupport.wi.w[:, b])))::Float64 for b in 1:m]

@test splitsupport.vi == 1
@test splitsupport.ni == float(data[:, ij[1]])
@test splitsupport.ui == [ij[1]; 0]
@test maximum(abs(splitsupport.wi.w - wi)) <= ε
@test maximum(abs(splitsupport.wi.c - ci)) <= ε
@test maximum(abs(splitsupport.wi.z - zi)) <= ε

wj = zeros(Float64, 4, m)
for col in 1:m
  for row in 1:4
    wj[row, col] = priorC.logγ[row] + splitlogω[row] +
                   logmarglik(data[col, ij[2]], 1, priorC.A[row, col],
                              priorC.B[row, col]) +
                   logcondmarglik(data[col, u], data[col, ij[2]], 1,
                                  priorC.A[row, col], priorC.B[row, col])
  end
end
zj = copy(wj)

cj = [log(sum(exp(splitsupport.wj.w[:, b])))::Float64 for b in 1:m]

@test splitsupport.vj == 2
@test splitsupport.nj == float(data[:, ij[2]]) + float(data[:, u])
@test splitsupport.uj == [ij[2]; u]
@test maximum(abs(splitsupport.wj.w - wj)) <= ε
@test maximum(abs(splitsupport.wj.c - cj)) <= ε
@test maximum(abs(splitsupport.wj.z - zj)) <= ε
