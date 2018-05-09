var fs = require("fs");
var path = require('path');
var webpack = require('webpack');

var srcDir = path.join(__dirname, 'website');
var targetDir = path.join(__dirname, '_target');

var HandlebarsPlugin = require("handlebars-webpack-plugin");
var ExtractTextPlugin = require("extract-text-webpack-plugin");
var DirectoryNameAsMain = require('webpack-directory-name-as-main');

var config = {
    entry: {
        main: path.join(srcDir, 'main.js')
    },

    plugins: [

        new HandlebarsPlugin({
            // path to hbs entry file(s)
            entry: path.join(srcDir, "*.hbs"),
            // output path and filename(s). This should lie within the webpacks output-folder
            // if ommited, the input filepath stripped of its extension will be used
            output: path.join(targetDir, "[name].html"),
            // data passed to main hbs template: `main-template(data)`
            data: require(path.join(srcDir, "data.json")),

            // hooks
            onBeforeSetup: function (Handlebars) {},
            onBeforeAddPartials: function (Handlebars, partialsMap) {},
            onBeforeCompile: function (Handlebars, templateContent) {},
            onBeforeRender: function (Handlebars, data) {},
            onBeforeSave: function (Handlebars, resultHtml, filename) {},
            onDone: function (Handlebars, filename) {}
        }),
        new ExtractTextPlugin("assets/[name].css"),
        new webpack.ResolverPlugin([
            new DirectoryNameAsMain()
        ]),
        new webpack.ProvidePlugin({
            $: "jquery",
            jQuery: "jquery",
            "window.jQuery": "jquery"
        })
    ],

    output: {
        path: targetDir,
        filename: "assets/[name].js"
    },

    resolve: {
        root: path.resolve(srcDir),
        modulesDirectories: [
            path.join(__dirname, 'node_modules')
        ],
        extensions: ['', '.js'],
        alias: {
            'babel-polyfill': path.join(__dirname, 'babel-polyfill/dist/polyfill.js')
        }
    },


    module: {
        loaders: [
            {
                test: /\.js$/,
                exclude: /(node_modules)/,
                loader: 'babel-loader',
                query: {
                    presets: ["es2015"]
                }
            },
            {
                test: /\.scss$/,
                loader: ExtractTextPlugin.extract(
                    'style',
                    `css!autoprefixer-loader?{browsers:["last 2 versions","> 5%"]}!sass-loader?includePaths[]=` + path.resolve(__dirname, "./node_modules/compass-mixins/lib")
                )
            },
            {
                test: /\.less$/,
                loader: ExtractTextPlugin.extract(
                    'style',
                    `css!autoprefixer-loader?{browsers:["last 2 versions","> 5%"]}!less`
                )
            },
            {
                test: /\.css$/,
                loader: ExtractTextPlugin.extract("style-loader", "css-loader")
            },
            { test: /\.(jpg|png|gif)$/, loader: "file-loader?name=images/[name].[md5:hash:base58:8].[ext]" },
            { test: /\.(woff|woff2)(\?v=[0-9]\.[0-9]\.[0-9]+)?$/, loader: "url-loader?limit=10000&minetype=application/font-woff&name=fonts/[name].[md5:hash:base58:8].[ext]" },
            { test: /\.(ttf|eot|svg)(\?v=[0-9]\.[0-9]\.[0-9]+)?$/, loader: "file-loader?name=fonts/[name].[md5:hash:base58:8].[ext]" }
        ]
    }
};

var watch = process.argv.indexOf('--watch') >= 0;
var minimize = process.argv.indexOf('--minimize') >= 0;
var compiler = webpack(config);

minimize && config.plugins.push(new webpack.optimize.UglifyJsPlugin({
    mangle: {
        except: ['$super', '$', 'exports', 'require']
    }
}));

var statOpts = {
    hash: true,
    timing: true,
    assets: true,
    chunks: false,
    children: false,
    version: false
};
if (watch) {
    compiler.watch({}, function (err, stats) {
            console.log(stats.toString(statOpts));
        }
    );
} else {
    compiler.run(function (err, stats) {
        console.log(stats.toString(statOpts));
    });
}
