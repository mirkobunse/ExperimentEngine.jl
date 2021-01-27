#
# ExperimentEngine.jl
# Copyright 2021 Mirko Bunse
#
#
# Conduct experiments in parallel.
#
#
# ExperimentEngine.jl is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ExperimentEngine.jl.  If not, see <http://www.gnu.org/licenses/>.
#
module ExperimentEngine

using Distributed, ProgressMeter
export AbstractTrial, conduct, resulttype, Trial

"""
    abstract type AbstractTrial end

Each experiment consists of multiple trials which need to implement the interface associated
with this abstract supertype.

# Example: An unfair coin toss

Each trial of the `CoinTrial` type tosses an unfair coin with probabilities `p` and `1-p`.
This toss implemented by comparing `rand()` with the probability that is specified through
the field `p` in the `CoinTrial`. The interface we need to implement must dispatch on our
trial type, to disambiguate between different `AbstractTrial` implementations:

    struct CoinTrial <: AbstractTrial
        p::Float64
    end

    ExperimentEngine.conduct(t::CoinTrial) = rand() < t.p

    ExperimentEngine.resulttype(::Type{CoinTrial}) = Bool

We can now conduct a thousand trials in parallel, using `p = 0.2` for instance.

    trials = [ CoinTrial(0.2) for _ in 1:1000 ]
    sum(conduct(trials))
"""
abstract type AbstractTrial end

"""
    conduct(t)

Conduct a single trial `t` or conduct a vector `t` of trials in parallel.
"""
conduct(t::AbstractTrial) =
    throw(ArgumentError("Not yet implemented for type $(typeof(t))"))

"""
    resulttype(::Type{T})

Return the result type of the `AbstractTrial` subclass `T`.
"""
resulttype(::Type{T}) where T <: AbstractTrial =
    throw(ArgumentError("ExperimentEngine.resulttype(::$T) not yet implemented"))

"""
    Trial(id, configuration)

This basic implementation of `AbstractTrial` stores nothing but a `configuration` of type
`AbstractDict`. The interface of `Trial` objects is implemented by dispatching on the `id`
identifier.

# Example: An unfair coin toss

Each trial with the `:coin` identifier tosses an unfair coin with probabilities `p` and `1-p`.
This toss implemented by comparing `rand()` with the probability that is specified through
the property `:p` of the configuration. The interface we need to implement must dispatch on
the identifier `:coin`, to disambiguate between different `Trial` implementations:

    ExperimentEngine.conduct(t::Trial{:coin,T}) where {T} =
        rand() < t.configuration[:p]

    ExperimentEngine.resulttype(::Type{Trial{:coin,T}}) where {T} = Bool

We can now conduct a thousand trials in parallel, using `p = 0.2` for instance.

    trials = [ Trial(:coin, Dict(:p => 0.2)) for _ in 1:1000 ]
    sum(conduct(trials))
"""
struct Trial{id,T} <: AbstractTrial
    configuration::T
end
Trial(id::Symbol, c::T) where T <: AbstractDict = Trial{id,T}(c)
Base.show(io::IO, t::Trial{id,T}) where {id, T} = print(io, "Trial{:", string(id), ",T}(configuration)")

function conduct(t::AbstractVector{T}) where {T <: AbstractTrial}
    r = resulttype(T)[] # local collection of results
    c = RemoteChannel(()->Channel{Union{resulttype(T),Nothing}}(length(t)), 1)
    p = Progress(length(t)) # progress bar
    @info "Distributing $(length(t)) trials over $(nworkers()) workers"
    @sync begin
        @async begin # this task collects the results and prints the progress bar
            m = take!(c) # block until the first result arrives
            while !isnothing(m)
                push!(r, m) # add to local results
                next!(p) # advance the progress bar
                m = take!(c) # wait for the next item
            end
        end
        @async begin # this task does the computation
            @distributed (+) for t_i in t
                put!(c, conduct(t_i))
                yield()
                0 # "return value" of each iteration; required to make (+) work
            end
            put!(c, nothing) # tell the printing task to finish
            yield()
        end
    end
    return r
end

end # module
