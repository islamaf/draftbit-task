CREATE TABLE components (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

INSERT INTO
    components (name)
VALUES
    ('button');

CREATE TABLE properties (
    id SERIAL PRIMARY KEY,
    component_id INT NOT NULL REFERENCES components(id),
    margin_top TEXT,
    margin_right TEXT,
    margin_bottom TEXT,
    margin_left TEXT,
    padding_top TEXT,
    padding_right TEXT,
    padding_bottom TEXT,
    padding_left TEXT
);

INSERT INTO
    properties (
        component_id,
        margin_top,
        margin_right,
        margin_bottom,
        margin_left,
        padding_top,
        padding_right,
        padding_bottom,
        padding_left
    )
VALUES
    (
        1,
        'auto',
        'auto',
        'auto',
        'auto',
        'auto',
        'auto',
        'auto',
        'auto'
    );