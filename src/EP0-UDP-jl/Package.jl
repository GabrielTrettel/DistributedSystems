module Package

using Serialization

export encode_and_split,
       decode_msg,
       decode,
       Datagram

include("NetUtils.jl")
using .NetUtils

mutable struct Datagram
    msg      :: Any
    msg_id   :: String
    sequence :: Int64
    total    :: Int64
    function Datagram(msg="", msg_id="-1", sequence=0, total=0)
        new(msg, msg_id, sequence, total)
    end
end


function encode(x::Any) :: Array{UInt8}
    iob = PipeBuffer()
    Serialization.serialize(iob, x)
    value = iob.data
    close(iob)
    return value
end


function decode(msgs::Vector{UInt8}) :: Any
    stream = PipeBuffer(msgs)
    original_data = Serialization.deserialize(stream)
    close(stream)
    return original_data
end


function encode_and_split(msg::Any) :: Array{Array{UInt8}}
    byte_array = encode(msg)
    msg_h = string(hash(msg))

    MAX_MSG_SIZE = Net_utils().mtu - sizeof(Datagram)

    MSG_SIZE = sizeof(byte_array)
    TOTAL_OF_PKGS = ceil(MSG_SIZE / MAX_MSG_SIZE)

    dg_vec::Array{Array{UInt8}} = []

    i = 1; j = MAX_MSG_SIZE
    seq = 1
    while i < MSG_SIZE
        msg_split = byte_array[i:min(MSG_SIZE, j)]

        dg = Datagram(msg_split, msg_h, seq, TOTAL_OF_PKGS)

        i += MAX_MSG_SIZE ; j+= MAX_MSG_SIZE ; seq += 1
        push!(dg_vec, encode(dg))
    end
    return dg_vec
end



function decode_msg(dgrams) :: Any
    total_msg = UInt8[]

    sort!(dgrams, by=dg -> dg.sequence) # Just to be sure

    for dg in dgrams
        append!(total_msg, dg.msg)
    end

    full_msg = decode(total_msg)
    return full_msg
end

end

# module

# using .Package

# @show sizeof(encode_and_split(read("/home/trettel/Documents/projects/DistributedSystems/peers/movie/Groundhog_Day.mp4")))
