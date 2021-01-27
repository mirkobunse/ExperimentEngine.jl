# Conduct experiments in parallel

Each experiment consists of multiple trials which need to implement the interface associated
with the `AbstractTrial` supertype.


## Example: An unfair coin toss

Each trial of the `CoinTrial` type tosses an unfair coin with probabilities `p` and `1-p`.
This toss implemented by comparing `rand()` with the probability that is specified through
the field `p` in the `CoinTrial`. The interface we need to implement must dispatch on our
trial type, to disambiguate between different `AbstractTrial` implementations:

```julia
struct CoinTrial <: AbstractTrial
    p::Float64
end

# this is the interface we need to implement
ExperimentEngine.conduct(t::CoinTrial) = rand() < t.p
ExperimentEngine.resulttype(::Type{CoinTrial}) = Bool
```

We can now conduct a thousand trials in parallel, using `p = 0.2` for instance.

```julia
trials = [ CoinTrial(0.2) for _ in 1:1000 ]
sum(conduct(trials))
```


## Trials with configurations

A straight-forward design of trials is to store some kind of `Dict`. This design is already
implemented in the `Trial` type. To distinguish between different experiments which use this
type, it becomes necessary to dispatching on the `id` identifier of `Trial` instances.

To implement the above example with the `Trial` type, we assume that the probability of the
unfair coin toss is specified through the property `:p` of the trial's configuration. To
implement the interface, we dispatch on the identifier `:coin`:

```julia
# no need to define a new type

ExperimentEngine.conduct(t::Trial{:coin,T}) where T = rand() < t.configuration[:p]
ExperimentEngine.resulttype(::Type{Trial{:coin,T}}) where T = Bool

trials = [ Trial(:coin, Dict(:p => 0.2)) for _ in 1:1000 ]
sum(conduct(trials))
```
