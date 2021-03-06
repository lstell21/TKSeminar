using CSV, DataFrames, LightGraphs, MetaGraphs, GraphPlot, Plots, StatsPlots
using PackageCompiler, Dictionaries, Distributed, Dates, JSON3, JSON

#load dataframe and find a certain ID
#df_ids = DataFrame!(CSV.File("df_ids.csv"))
df_en = DataFrame!(CSV.File("df_en.csv"))
const df_en_const = df_en[1:1000000,:]


function create_RT_csv()
    #read the highest RT texts
    tweet_dict = JSON.parsefile("tweets_RT_UTF8.txt")
    #create dict with the texts
    tweet_ID_text_dict = Dict()
    tweet_ID_name_dict = Dict()
    for elm in tweet_dict
        tweet_ID_text_dict[elm["id"]] = elm["full_text"]
        tweet_ID_name_dict[elm["in_reply_to_user_id_str"]] = elm["in_reply_to_screen_name"]
    end
    #build a dict of the id - screen names
    #and add it to the RT df
    insertcols!(c,2, "full_text" => ["" for i in nrow(c)])
    insertcols!(c,3, "screen_name" => ["" for i in nrow(c)])
    for row in eachrow(c)
        try
            row."full_text" = tweet_ID_text_dict[row.Id]
        catch
        end
        try
            row."screen_name" = tweet_ID_name_dict[string(row."From-User-Id")]
        catch
        end
    end
    #save the DF
    CSV.write("df_RT.csv",c)
end

#added an index since accessing the row index during iteration seems impossible (or well hidden)
# CSV.write("df_en.csv",df_en)
#df_en.:index = collect(1:nrow(df_en))

function create_selected_dfs(df_en)
    #select the million most retweeted messages
    df_rts = sort!(df_en, (:"Retweet-Count"))
    df_rts = df_rts[end-1000000:end,:]

    #select each nth row to reduce the dataframe to 1 million tweetssoun
    df_1ml = filter(row->(row.:index%21)==0,df_en)

    #select the million/100.000 most polarized tweets
    df_pol = sort!(df_en, (:"Score"))
    df_pol = vcat(df_pol[1:50000,:],df_pol[end-50000:end,:])

    return df_rts,df_1ml,df_pol
end

a,b,c = create_selected_dfs(df_en)
# write_df = DataFrame("Id" => a[:,"Id"])
# CSV.write("df_ids_RTs.csv",write_df)

#TODO: IDEAS for analyzing
#use of hashtag and negativity/positivity
#most active users (most from)-> what did they spread?
#most influential users (most RTs) -> what did they spread?
#network with most RTetd content
#color positivity/negativity in responses

function create_graph(df_en)
    meta_graph = MetaGraph(SimpleGraph())
    #get unique IDs from the DF, add those vertices to the graph and give it the respective ID
    unique_ids_from = Set(unique(df_en."From-User-Id"))
    unique_ids_to = Set(unique(df_en."To-User-Id"))
    unique_ids = collect(union(unique_ids_to,unique_ids_from))
    #add the vertices to the graph'
    add_vertices!(meta_graph, length(unique_ids))
    #create a dict with the unique ids and their position in the grap
    indexarr = [1:length(unique_ids)...]
    unique_ids_new_dict = Dictionary(unique_ids,indexarr)
    #and add the edges
    @simd for row in eachrow(df_en)
        add_edge!(meta_graph,unique_ids_new_dict[row."From-User-Id"],unique_ids_new_dict[row."To-User-Id"])
    end
    return meta_graph
end

function centralities(meta_graph)
    #show a degree histogram
    display(StatsPlots.histogram(degree_histogram(temp_graph),yaxis=(:log10), bins=150))

    #these are too slow for 1ml networks
    #print the global cc
    #print("global cc is $(global_clustering_coefficient(meta_graph))")
    #and the betweenness with 0s removed to shrink the graph somewhat
    # betweenness = betweenness_centrality(meta_graph)
    # betweenness_filtered = filter(x->x!=0, betweenness)
    # display(histogram(betweenness_filtered))
end

c = DataFrame!(CSV.File("df_RT.csv"))
c_small = c[end-2005:end,:]
c_small_graph = create_graph(c_small)
#replace missing screennames with id
c_small = coalesce.(c_small,"Id")
plot_graph(c_small_graph,c_small)

function plot_graph(meta_graph,df_en)
    #plot the graph with node labels for the underlying graph
    display(gplot(meta_graph;nodelabel = df_en[1:nrow(df_en),"screen_name"]))
end

function create_histogram(meta_graph)
    display(StatsPlots.histogram(degree_histogram(meta_graph),yaxis=(:log10), bins=150))
end

#which functions?
#for each x days in timeframe
function for_x_days(x,df_en)
    #compute the time passed
    first_day = Date(df_en[1,"Created-At"][1:end-8],"m/d/y")
    last_day = Date(df_en[end,"Created-At"][1:end-8],"m/d/y")
    passed_days = last_day-first_day
    #slice these days in x pieces, select the range in the DataFrame
    timeslots = Int(ceil(passed_days.value/x))
    prev = 1
    df_share = Int(round(nrow(df_en)/timeslots))
    print("timeslts are $timeslots")
    for i in 1:timeslots
        print("from $prev to $i time $x")
        df_temp = df_en[prev:i*df_share,:]
        #here we can do stuff
        #create the graph
        print("tempdf has $(nrow(df_temp))")
        graph = create_graph(df_temp)
        #and plot it
        plot_graph(graph)
        #also compute the centralities
        #centralities(graph)
        #and increment the counter
        prev = prev+df_share
    end
end

for_x_days(10,df_en_const[1:10000,:])

using TikzGraphs
graph = create_graph(df_en_const[1:10000,:])
using DrawSimpleGraphs
@time gplot(graph)
using GraphRecipes
@time graphplot(graph)
embed(G,:combin)
using SimpleDrawing
@time DrawSimpleGraphs.newdraw(g)

using SimpleGraphs, DrawSimpleGraphs, Plots
 G = Cube(4)
 sg = SimpleGraph(graph)
draw(sg)
typeof(G)
SimpleGraph{String}(graph)

using Makie
scene()
Makie.scatter!(graph)
