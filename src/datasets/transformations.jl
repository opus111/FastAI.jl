
# mapobs

struct MappedData
    f
    data
end

Base.show(io::IO, data::MappedData) = print(io, "mapobs($(data.f), $(data.data))")
LearnBase.nobs(data::MappedData) = nobs(data.data)
LearnBase.getobs(data::MappedData, idx::Int) = data.f(getobs(data.data, idx))
LearnBase.getobs(data::MappedData, idxs::AbstractVector) = data.f.(getobs(data.data, idxs))

"""
    mapobs(f, data)

Lazily map `f` over the observations in a data container `data`.

```julia
data = 1:10
getobs(data, 8) == 8
mdata = mapobs(-, data)
getobs(mdata, 8) == -8
```
"""
mapobs(f, data) = MappedData(f, data)


"""
    mapobs(fs, data)

Lazily map each function in tuple `fs` over the observations in data container `data`.
Returns a tuple of transformed data containers.
"""
mapobs(fs::Tuple, data) = Tuple(mapobs(f, data) for f in fs)

# filterobs

"""
    filterobs(f, data)

Return a subset of data container `data` including all indices `i` for
which `f(getobs(data, i)) === true`.

```julia
data = 1:10
nobs(data) == 10
fdata = filterobs(>(5), data)
nobs(fdata) == 5
```
"""
function filterobs(f, data; iterfn = _iterobs)
    return datasubset(data, [i for (i, obs) in enumerate(iterfn(data)) if f(obs)])
end

_iterobs(data) = [getobs(data, i) for i in 1:nobs(data)]


# groupobs

"""
    groupobs(f, data)

Split data container data `data` into different data containers, grouping
observations by `f(obs)`.

```julia
data = -10:10
datas = groupobs(>(0), data)
length(datas) == 2
```
"""
function groupobs(f, data)
    groups = Dict{Any, Vector{Int}}()
    for i in 1:nobs(data)
        group = f(getobs(data, i))
        if !haskey(groups, group)
            groups[group] = [i]
        else
            push!(groups[group], i)
        end
    end
    return Tuple(datasubset(data, groups[group])
        for group in sort(collect(keys(groups))))
end

# joinobs

struct JoinedData{T, N}
    datas::NTuple{N, T}
    ns::NTuple{N, Int}
end

JoinedData(datas) = JoinedData(datas, nobs.(datas))

LearnBase.nobs(data::JoinedData) = sum(data.ns)
function LearnBase.getobs(data::JoinedData, idx)
    for (i, n) in enumerate(data.ns)
        if idx <= n
            return getobs(data.datas[i], idx)
        else
            idx -= n
        end
    end
end

"""
    joinobs(datas...)

Concatenate data containers `datas`.

```julia
data1, data2 = 1:10, 11:20
jdata = joinobs(data1, data2)
getobs(jdata, 15) == 15
```
"""
joinobs(datas...) = JoinedData(datas)


# TODO: NamedTupleData transformation
#
# mdata = mapobs(data, (col1 = f1, col2 = f2))
# getobs(mdata, 1) == (col1 = f1(getobs(data, 1)), col2 = f2(getobs(data, 1)))
# getobs(mdata.col1, 1) == f1(getobs(data, 1))
#
# Useful for datasets where you want to split off the targets, e.g. to avoid loading the
# images.
