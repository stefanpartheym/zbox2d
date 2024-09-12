const std = @import("std");
const rl = @import("raylib");
const zb = @import("zbox2d");

const State = struct {
    /// Controls wether game is running or not.
    running: bool,
    /// Controls wether physics are enabled or not.
    physics_enabled: bool = true,
    /// Controls wether debug mode is enabled or not.
    debug_enabled: bool = false,
};

const Entity = struct {
    shape: zb.b2ShapeId,
    size: rl.Vector2,
    color: rl.Color,
};

pub fn main() !void {
    // Settings:
    // Tweak these values to play around with this example.
    const width = 800;
    const height = 600;
    const fps = 60;
    // Enable this, if your're using a monitor with high resolution such as 4K.
    const enable_highdpi = false;
    // PPM: Pixels per meter (100px = 1m)
    const physics_ppm = 100.0;
    const physics_time_step = 1.0 / 60.0;
    const physics_sub_step_count = 6;
    const physics_box_restitution = 0.25;

    // Setup raylib.
    rl.setConfigFlags(.{ .window_highdpi = enable_highdpi });
    rl.setTargetFPS(fps);
    rl.initWindow(width, height, "zbox2d - simple visualized example");
    defer rl.closeWindow();

    // Setup box2d world.
    zb.b2SetLengthUnitsPerMeter(physics_ppm);
    var worldDef = zb.b2DefaultWorldDef();
    worldDef.gravity.y = 9.81 * physics_ppm;
    const world = zb.b2CreateWorld(&worldDef);
    defer zb.b2DestroyWorld(world);

    // box2d: Setup static ground entity.
    const ground_size = rl.Vector2{ .x = 500, .y = 50 };
    var ground_def = zb.b2DefaultBodyDef();
    // Place ground at the bottom of the screen with 50px offset.
    ground_def.position = zb.b2Vec2{ .x = width / 2, .y = height - ground_size.y / 2 - 50 };
    const ground_body = zb.b2CreateBody(world, &ground_def);
    // NOTE: In box2d we need to take half of width and height when creating the
    // polygon, because box2d calculates the sizes from the body's center point.
    const ground_polygon = zb.b2MakeBox(ground_size.x / 2, ground_size.y / 2);
    const ground_shape_def = zb.b2DefaultShapeDef();
    const ground_shape = zb.b2CreatePolygonShape(ground_body, &ground_shape_def, &ground_polygon);

    const ground_entity = Entity{
        .size = ground_size,
        .shape = ground_shape,
        .color = rl.Color.green,
    };

    // box2d: Setup dynamic box entity to fall into ground by gravitational
    // force.
    const box_size = rl.Vector2{ .x = 100, .y = 100 };
    var box_body_def = zb.b2DefaultBodyDef();
    box_body_def.type = zb.b2_dynamicBody;
    // Place box at the top of the screen with 50px offset.
    box_body_def.position = zb.b2Vec2{ .x = width / 2, .y = 50 };
    const box_body = zb.b2CreateBody(world, &box_body_def);
    const box_polygon = zb.b2MakeBox(box_size.x / 2, box_size.y / 2);
    var box_shape_def = zb.b2DefaultShapeDef();
    box_shape_def.density = 1.0;
    box_shape_def.friction = 0.3;
    // NOTE: The restitution defines how "bouncy" the body is.
    // 1 = The body bounces off to its original position.
    // 0 = The body does not bounce at all.
    box_shape_def.restitution = physics_box_restitution;
    const box_shape = zb.b2CreatePolygonShape(box_body, &box_shape_def, &box_polygon);

    const box_entity = Entity{
        .size = box_size,
        .shape = box_shape,
        .color = rl.Color.maroon,
    };

    // Main loop.
    var state = State{ .running = true };
    while (state.running) {
        handleInput(&state);

        // Reset box position if necessary.
        if (rl.isKeyPressed(rl.KeyboardKey.key_r)) {
            const body = zb.b2Shape_GetBody(box_entity.shape);
            zb.b2Body_Disable(body);
            zb.b2Body_SetTransform(
                body,
                zb.b2Vec2{ .x = width / 2, .y = 150 },
                zb.b2Body_GetRotation(body),
            );
            zb.b2Body_Enable(body);
        }

        // Update physics.
        if (state.physics_enabled) {
            zb.b2World_Step(world, physics_time_step, physics_sub_step_count);
        }

        // Render scene.
        rl.beginDrawing();
        rl.clearBackground(rl.Color.dark_gray);

        renderEntity(ground_entity);
        renderEntity(box_entity);

        if (state.debug_enabled) {
            debugRenderEntity(ground_entity);
            debugRenderEntity(box_entity);
            rl.drawFPS(10, 10);
        }

        const text_x = width - 300;
        const font_size = 24;
        rl.drawText("[Q]  quit", text_x, font_size * 1, font_size, rl.Color.black);
        rl.drawText("[P]  toggle physics", text_x, font_size * 2, font_size, rl.Color.black);
        rl.drawText("[R]  reset", text_x, font_size * 3, font_size, rl.Color.black);
        rl.drawText("[F1] toggle debug mode", text_x, font_size * 4, font_size, rl.Color.black);
        if (state.physics_enabled) {
            rl.drawText("Physics enabled", text_x, font_size * 6, font_size, rl.Color.red);
        } else {
            rl.drawText("Physics disabled", text_x, font_size * 6, font_size, rl.Color.gray);
        }

        rl.endDrawing();
    }
}

/// Handle keyboard input.
fn handleInput(state: *State) void {
    // Toggle physics.
    if (rl.isKeyPressed(rl.KeyboardKey.key_p)) {
        state.physics_enabled = !state.physics_enabled;
    }

    // Toggle debug mode.
    if (rl.isKeyPressed(rl.KeyboardKey.key_f1)) {
        state.debug_enabled = !state.debug_enabled;
    }

    // Close window when [ESC] or [Q] is pressed or if window is closed
    // manually.
    if (rl.isKeyPressed(rl.KeyboardKey.key_q) or rl.windowShouldClose()) {
        state.running = false;
    }
}

/// Convert a box2d `b2Vec2` to a raylib `Vector2`.
fn toVector2(b2vec: zb.b2Vec2) rl.Vector2 {
    return rl.Vector2{ .x = b2vec.x, .y = b2vec.y };
}

/// Render given entity.
fn renderEntity(entity: Entity) void {
    const body = zb.b2Shape_GetBody(entity.shape);
    const pos = zb.b2Body_GetWorldPoint(
        body,
        zb.b2Vec2{ .x = -entity.size.x / 2, .y = -entity.size.y / 2 },
    );
    const rotation = zb.b2Body_GetRotation(body);
    const radians = zb.b2Rot_GetAngle(rotation);

    rl.drawRectanglePro(
        .{
            .x = pos.x,
            .y = pos.y,
            .width = entity.size.x,
            .height = entity.size.y,
        },
        .{ .x = 0, .y = 0 },
        180.0 / std.math.pi * radians,
        entity.color,
    );
}

/// Render debug information for given entity.
fn debugRenderEntity(entity: Entity) void {
    const body = zb.b2Shape_GetBody(entity.shape);
    const hx = entity.size.x / 2;
    const hy = entity.size.y / 2;

    // Draw upper-left point.
    const point_ut = zb.b2Body_GetWorldPoint(body, zb.b2Vec2{ .x = -hx, .y = -hy });
    rl.drawCircleV(toVector2(point_ut), 5.0, rl.Color.black);
    // Draw center point.
    const point_center = zb.b2Body_GetWorldPoint(body, zb.b2Vec2{ .x = 0.0, .y = 0.0 });
    rl.drawCircleV(toVector2(point_center), 5.0, rl.Color.blue);
    // Draw lower-right point.
    const point_lr = zb.b2Body_GetWorldPoint(body, zb.b2Vec2{ .x = hx, .y = hy });
    rl.drawCircleV(toVector2(point_lr), 5.0, rl.Color.red);
}
