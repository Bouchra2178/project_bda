//requete 1
db.hotel.find({ etoiles: 3 }, { _id: 0, nomhotel: 1 });

//requete 2
db.reservation.aggregate([{
        $group: {
            _id: "$numhotel",
            count: { $sum: 1 },
        },
    },
    {
        $lookup: {
            from: "hotel",
            localField: "_id",
            foreignField: "numhotel",
            as: "hotelInfo",
        },
    },
    {
        $project: {
            _id: 0,
            NOMHOTEL: { $arrayElemAt: ["$hotelInfo.nomhotel", 0] },
            NBRRESERVATION: "$count",
        },
    },
    { $sort: { NBRRESERVATION: -1 } },
    { $out: "Hotels_NbResv" },
]);
//.explain()
//requete 3
db.hotel.aggregate([{
        $match: {
            "chambre.prixnuit": { $lte: 6000 },
        },
    },
    {
        $out: "HotelsPas-cher",
    },
]);

//requete 4
db.hotel.aggregate([
    { $unwind: "$evaluation" },
    {
        $group: {
            _id: {
                num: "$numhotel",
                nom: "$nomhotel",
            },
            count: { $sum: 1 },
            total: { $sum: "$evaluation.note" },
        },
    },
    {
        $project: {
            noteglobale: { $divide: ["$total", "$count"] },
        },
    },
    {
        $match: {
            noteglobale: { $gte: 5 },
        },
    },
    { $sort: { noteglobale: -1 } }
]);

//requete 5
db.reservation.aggregate([
    { $match: { numclient: 40 } },
    {
        $lookup: {
            from: "hotel",
            localField: "numhotel",
            foreignField: "numhotel",
            as: "info",
        },
    },
    {
        $project: {
            nom_hotel: "$info.nomhotel",
            NUMCHAMBRE: "$numchambre",
            CLIENT: "$numclient",
            DATE: "$datearrivee",
        },
    },
]);
db.reservation.aggregate([
    { $match: { numclient: 40 } },
    {
        $project: {
            nom_hotel: db.hotel.find({ numhotel: "numhotel" }, { _id: 0, nomhotel: 1 }).next().nomhotel,
            NUMCHAMBRE: "$numchambre",
            CLIENT: "$numclient",
            DATE: "$datearrivee",
        },
    },
]);
//requete 6 ,j'ai chercher dirctement sur le numclient
db.hotel.aggregate([
    { $unwind: "$evaluation" },
    {
        $match: {
            "evaluation.numclient": 1
        },
    },
    {
        $project: {
            Client: "$evaluation.numclient",
            nom_hotel: "$nomhotel",
            NOTE: "$evaluation.note",
            DATE: "$evaluation.date",
        },
    },
]);

//requete 6 ,j'ai chercher sur le mail du client
db.hotel.aggregate([
    { $unwind: "$evaluation" },
    {
        $match: {
            "evaluation.numclient": db.client
                .find({ email: "BELHAMIDI@gmail.com" }, { _id: 0, numclient: 1 })
                .next().numclient,
        },
    },
    {
        $project: {
            Client: "$evaluation.numclient",
            nom_hotel: "$nomhotel",
            NOTE: "$evaluation.note",
            DATE: "$evaluation.date",
        },
    },
]);

//requete 7
db.hotel.updateMany({ etoiles: 5 }, {
    $inc: {
        "chambre.$[].prixnuit": 2000,
    },
});


//requete 8

var mapFunction = function() {
    emit(this.numhotel, 1);
};

var reduceFunction = function(key, values) {
    return Array.sum(values);
};
db.reservation.mapReduce(mapFunction, reduceFunction, {
    out: "Hotels_NbResv2",
});

db.Hotels_NbResv2.aggregate([
    { $sort: { value: -1 } },
    { $out: "Hotels_NbResv2" },
]);