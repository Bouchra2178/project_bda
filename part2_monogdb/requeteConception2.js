//requete 1
db.hotel.find({ etoiles: 3 }, { _id: 0, nomhotel: 1 });

//requete 2
db.hotel.aggregate([
    { $unwind: "$reseravtion" },
    {
        $group: {
            _id: "$nomhotel",
            count: { $sum: 1 },
        },
    },
    {
        $project: {
            _id: 0,
            Hotel: "$_id",
            NBRRESERVATION: "$count",
        },
    },

    { $sort: { NBRRESERVATION: -1 } },
    { $out: "Hotels_NbResv" },
]);
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
            total: { $avg: "$evaluation.note" },
        },
    },
    {
        $project: {
            numhotel: "$_id.num",
            nomhotel: "$_id.nom",
            noteglobale: "$total",
        },
    },
    {
        $match: {
            noteglobale: { $gte: 5 },
        },
    },
    { $sort: { noteglobale: -1 } },
]);

//requete 5

db.hotel.aggregate([
    { $unwind: "$reseravtion" },
    {
        $match: {
            "reseravtion.numclient": db.client
                .find({ email: "BELHAMIDI@gmail.com" }, { _id: 0, numclient: 1 })
                .next().numclient,
        },
    },
    {
        $project: {
            Nomhotel: "$nomhotel",
            Numchambre: "$reseravtion.numchambre",
            Date: "$reseravtion.datearrivee",
        },
    },
]);

//requete 6
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

//requet 8

var mapFunction = function() {
    emit(this.nomhotel, this.reseravtion.length);
};

var reduceFunction = function(key, values) {
    return values[0];
};

db.hotel.mapReduce(mapFunction, reduceFunction, {
    out: "Hotels_NbResv2",
});

db.Hotels_NbResv2.aggregate([
    { $sort: { value: -1 } },
    { $out: "Hotels_NbResv2" },
]);

db.Hotels_NbResv2.find();