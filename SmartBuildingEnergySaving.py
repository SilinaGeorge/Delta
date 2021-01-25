import pandas as pd
import plotly.express as px 
import plotly.graph_objects as go
import dash 
import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output, State
from dash import Dash
import dash_bootstrap_components as dbc
from datetime import date
import sys
import datetime
import os

app = dash.Dash(__name__)
app = dash.Dash(
    external_stylesheets=[dbc.themes.SOLAR],
    meta_tags=[
        {"name": "viewport", "content": "width=device-width, initial-scale=1"}
    ],
)
app.config['suppress_callback_exceptions'] = True

CO2_SAVED_FINAL = pd.read_csv(os.path.join(os.getcwd(),"C02_SAVED_FINAL_BY_USING_LESSER_ENERGY.rpt"))

sidebar_header = dbc.Row(
    [
        dbc.Col(html.H2("Energy Saving", className="display-6")),
        #html.Button('Submit', id='TotalSavedC02-button', n_clicks=0, color="primary"),
        dbc.Col(
            [
                html.Button(
                    html.Span(className="navbar-toggler-icon"),
                    className="navbar-toggler",
                    style={
                        "color": "rgba(0,0,0,.5)",
                        "border-color": "rgba(0,0,0,.1)",
                    },
                    id="navbar-toggle",
                ),
                html.Button(
                    html.Span(className="navbar-toggler-icon"),
                    className="navbar-toggler",
                    style={
                        "color": "rgba(0,0,0,.5)",
                        "border-color": "rgba(0,0,0,.1)",
                    },
                    id="sidebar-toggle",
                ),
            ],
            width="auto",
            align="center",
        ),
    ]
)

sidebar = html.Div(
    [
        sidebar_header,
            html.Div(
                [
                    html.Hr(),
                    html.Label('Date:'),
                    html.Div([
                    dcc.DatePickerSingle(
                        month_format='MMM Do, YY',
                        max_date_allowed=date(2019,12,31),
                        min_date_allowed=date(2019,1,1),
                        style={'width': '100%'},
                        id='my-date-picker-single',
                    )  ,  
                    html.Div(id='output-container-date-picker-single')
                ]),
                html.Div([
                    html.Label('Time:', style={'margin-top': '4%'}),             
                    dcc.Dropdown(
                        style = {
                            'width': '100%',
                            'margin-right': '10%',
                        },
                        id='time-dropdown',
                        options=[
                            {'label': '0:00', 'value': 0,},
                            {'label': '1:00', 'value': 1},
                            {'label': '2:00', 'value': 2},
                            {'label': '3:00', 'value': 3},
                            {'label': '4:00', 'value': 4},
                            {'label': '5:00', 'value': 5},
                            {'label': '6:00', 'value': 6},
                            {'label': '7:00', 'value': 7},
                            {'label': '8:00', 'value': 8},
                            {'label': '9:00', 'value': 9},
                            {'label': '10:00', 'value': 10},
                            {'label': '11:00', 'value': 11},
                            {'label': '12:00', 'value': 12},
                            {'label': '13:00', 'value': 13},
                            {'label': '14:00', 'value': 14},
                            {'label': '15:00', 'value': 15},
                            {'label': '16:00', 'value': 16},
                            {'label': '17:00', 'value': 17},
                            {'label': '18:00', 'value': 18},
                            {'label': '19:00', 'value': 19},
                            {'label': '20:00', 'value': 20},
                            {'label': '21:00', 'value': 21},
                            {'label': '22:00', 'value': 22},
                            {'label': '23:00', 'value': 23},
                        ],
                        value=-1,
                        placeholder="Time",
                    ),
                    dbc.Button(children='Submit', id='submit-button', color="primary", className="mr-1", style={"margin-left":"35%","margin-top":"5%"}),
                    html.Div(id='dd-output-container2')
                ]),
                
                ],        
            ),      
    ],
    id="sidebar",
)
content = html.Div(id="page-content")

app.layout = html.Div([dcc.Location(id="url"), sidebar, content])


@app.callback(Output("page-content", "children"), [Input("url", "pathname")])
def render_page_content(pathname):
    if pathname == "/":
        return dcc.Graph(id="choropleth")
    return dbc.Jumbotron(
        [
            html.H1("404: Not found", className="text-danger"),
            html.Hr(),
            html.P(f"The pathname {pathname} was not recognised..."),
        ]
    )


@app.callback(
    Output("sidebar", "className"),
    [Input("sidebar-toggle", "n_clicks")],
    [State("sidebar", "className")],
)
def toggle_classname(n, classname):
    if n and classname == "":
        return "collapsed"
    return ""


@app.callback(
    Output("collapse", "is_open"),
    [Input("navbar-toggle", "n_clicks")],
    [State("collapse", "is_open")],
)
def toggle_collapse(n, is_open):
    if n:
        return not is_open
    return is_open

@app.callback(
    Output("choropleth", "figure"),
    Input('submit-button', 'n_clicks'),
    [State('my-date-picker-single', 'date'),
    State('time-dropdown', 'value'),
    ])
    
def update_output3(n_click,date_value,value):
    print("here",date_value)
    if ((date_value is not None) and (value != -1)):
        
        date_object = date.fromisoformat(date_value)
        datetime_object = datetime.datetime.combine(date_object, datetime.time(value, 0))
        date_string = datetime_object.strftime('%Y-%m-%d %H:%M:%S')

        CO2_SAVED_FINAL.filter(items=[date_string])
        fig = px.choropleth(CO2_SAVED_FINAL,  # Input Pandas DataFrame
                            locations="state",  # DataFrame column with locations
                            color="TOTAL_CO2_SAVED",  # DataFrame column with color values
                            hover_name="state", # DataFrame column hover info
                            locationmode = 'USA-states') # Set to plot as US States
        fig.update_layout(
            title_text = 'State Rankings', # Create a Title
            geo_scope='usa',  # Plot only the USA instead of globe
        )
        #fig.show()  # Output the plot to the screen
        return fig
    return px.choropleth()

if __name__ == '__main__':
    app.run_server(debug=True)