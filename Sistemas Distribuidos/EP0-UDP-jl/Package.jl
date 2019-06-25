module Package end

export encode_and_split,
       decode_msg,
       decode,
       Datagram


include("NetUtils.jl")


using Serialization

mutable struct Datagram
    msg::Any
    command::String
    sequence::Int64
    total::Int64
    owner::String
end


function encode(x::Any) :: Vector{UInt8}
    iob = IOBuffer()
    Serialization.serialize(iob, x)
    return iob.data
end

function encode_and_split(msg::Any, owner::String, command::String="")
    byte_array = encode(msg)

    MAX_MSG_SIZE = Net_utils().mtu - (sizeof(Datagram) - sizeof(owner) - sizeof(command))
    # MAX_MSG_SIZE = 1024 - sizeof(Datagram)

    MSG_SIZE = sizeof(byte_array)
    TOTAL_OF_PKGS = ceil(MSG_SIZE / MAX_MSG_SIZE)

    dg_vec = []

    i = 1; j = MAX_MSG_SIZE
    seq = 1
    while i < MSG_SIZE
        msg_split = byte_array[i:min(MSG_SIZE, j)]

        dg = Datagram(msg_split,command,seq,TOTAL_OF_PKGS,owner)

        i += MAX_MSG_SIZE ; j+= MAX_MSG_SIZE ; seq += 1
        push!(dg_vec, encode(dg))

    end

    return dg_vec

end



function decode(msgs::Vector{UInt8})
    stream = IOBuffer(msgs)
    original_data = Serialization.deserialize(stream)
end



function decode_msg(dgrams::Vector{Datagram}) :: Any
    total_msg = UInt8[]
    sort!(dgrams, by=dg -> dg.sequence)

    for dg in dgrams
        append!(total_msg, dg.msg)
    end

    full_msg = decode(total_msg)
end



        # splitted = encode_and_split("a"^1024,"trettfl")
        # sizeof(splitted[1])
        # msg = decode_msg(splitted)
